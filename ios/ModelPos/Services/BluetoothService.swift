// 蓝牙服务 - 管理与设备的 BLE 连接

import Foundation
import CoreBluetooth
import Combine

/// 蓝牙状态
enum BluetoothState: Equatable {
    case unknown
    case poweredOff
    case poweredOn
    case unauthorized
    case unsupported
    case scanning
    case connecting
    case connected
    case disconnected
}

/// 发现的设备
struct DiscoveredDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
    let macAddress: String?
    let deviceType: DeviceType?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}

/// 姿态数据
struct PostureData {
    let postureType: String
    let isCorrect: Bool
    let confidence: Float
    let timestamp: Date
}

/// 蓝牙服务
@MainActor
final class BluetoothService: NSObject, ObservableObject {
    static let shared = BluetoothService()
    
    // MARK: - Published 属性
    
    @Published private(set) var state: BluetoothState = .unknown
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var connectedDevice: DiscoveredDevice?
    @Published private(set) var latestPosture: PostureData?
    @Published private(set) var errorMessage: String?
    
    // MARK: - 私有属性
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var postureCharacteristic: CBCharacteristic?
    private var settingsCharacteristic: CBCharacteristic?
    
    private let serviceUUID = CBUUID(string: AppConfig.detectorServiceUUID)
    private let postureCharUUID = CBUUID(string: AppConfig.postureCharUUID)
    private let settingsCharUUID = CBUUID(string: AppConfig.settingsCharUUID)
    
    private var scanTimer: Timer?
    private var postureDataSubject = PassthroughSubject<PostureData, Never>()
    
    /// 姿态数据流
    var postureDataPublisher: AnyPublisher<PostureData, Never> {
        postureDataSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 初始化
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: nil, queue: nil)
    }
    
    /// 启动蓝牙管理
    func start() {
        centralManager.delegate = self
    }
    
    // MARK: - 扫描
    
    /// 开始扫描设备
    func startScan() {
        guard state == .poweredOn || state == .disconnected else {
            if state == .poweredOff {
                errorMessage = "请打开蓝牙"
            }
            return
        }
        
        discoveredDevices = []
        state = .scanning
        
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // 设置扫描超时
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.bleScanTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopScan()
            }
        }
    }
    
    /// 停止扫描
    func stopScan() {
        scanTimer?.invalidate()
        scanTimer = nil
        centralManager.stopScan()
        
        if state == .scanning {
            state = connectedPeripheral != nil ? .connected : .disconnected
        }
    }
    
    // MARK: - 连接
    
    /// 连接设备
    func connect(to device: DiscoveredDevice) {
        stopScan()
        state = .connecting
        centralManager.connect(device.peripheral, options: nil)
    }
    
    /// 断开连接
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        connectedDevice = nil
        postureCharacteristic = nil
        settingsCharacteristic = nil
        state = .disconnected
    }
    
    // MARK: - 发送设置
    
    /// 发送设置到设备
    func sendSettings(_ settings: Data) {
        guard let characteristic = settingsCharacteristic,
              let peripheral = connectedPeripheral else {
            errorMessage = "设备未连接"
            return
        }
        
        peripheral.writeValue(settings, for: characteristic, type: .withResponse)
    }
    
    /// 发送反馈触发命令
    func triggerFeedback(type: FeedbackType) {
        let data = Data([type.rawValue])
        sendSettings(data)
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .unknown:
                state = .unknown
            case .resetting:
                state = .unknown
            case .unsupported:
                state = .unsupported
            case .unauthorized:
                state = .unauthorized
            case .poweredOff:
                state = .poweredOff
            case .poweredOn:
                state = .poweredOn
            @unknown default:
                state = .unknown
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            // 解析广播数据中的设备信息
            let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "未知设备"
            
            var macAddress: String? = nil
            var deviceType: DeviceType? = nil
            
            // 从 Manufacturer Data 中解析 MAC 地址和设备类型
            if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
               manufacturerData.count >= 8 {
                // 前6字节是 MAC 地址
                macAddress = manufacturerData.prefix(6).map { String(format: "%02X", $0) }.joined(separator: ":")
                // 第7字节是设备类型
                deviceType = manufacturerData[6] == 0 ? .detector : .feedbacker
            }
            
            let device = DiscoveredDevice(
                id: peripheral.identifier,
                name: name,
                rssi: RSSI.intValue,
                peripheral: peripheral,
                macAddress: macAddress,
                deviceType: deviceType
            )
            
            // 更新或添加设备
            if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                discoveredDevices[index] = device
            } else {
                discoveredDevices.append(device)
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedPeripheral = peripheral
            peripheral.delegate = self
            peripheral.discoverServices([serviceUUID])
            
            // 更新连接状态
            if let device = discoveredDevices.first(where: { $0.id == peripheral.identifier }) {
                connectedDevice = device
            }
            state = .connected
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            state = .disconnected
            errorMessage = "连接失败: \(error?.localizedDescription ?? "未知错误")"
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectedPeripheral = nil
            connectedDevice = nil
            postureCharacteristic = nil
            settingsCharacteristic = nil
            state = .disconnected
            
            if let error = error {
                errorMessage = "连接断开: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                errorMessage = "服务发现失败: \(error.localizedDescription)"
                return
            }
            
            guard let services = peripheral.services else { return }
            
            for service in services {
                if service.uuid == serviceUUID {
                    peripheral.discoverCharacteristics([postureCharUUID, settingsCharUUID], for: service)
                }
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error = error {
                errorMessage = "特征发现失败: \(error.localizedDescription)"
                return
            }
            
            guard let characteristics = service.characteristics else { return }
            
            for characteristic in characteristics {
                if characteristic.uuid == postureCharUUID {
                    postureCharacteristic = characteristic
                    // 订阅姿态数据通知
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if characteristic.uuid == settingsCharUUID {
                    settingsCharacteristic = characteristic
                }
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error = error {
                errorMessage = "数据接收失败: \(error.localizedDescription)"
                return
            }
            
            guard let data = characteristic.value else { return }
            
            if characteristic.uuid == postureCharUUID {
                // 解析姿态数据
                parsePostureData(data)
            }
        }
    }
    
    /// 解析姿态数据
    private func parsePostureData(_ data: Data) {
        guard data.count >= 6 else { return }
        
        // 数据格式: [姿态类型 1B][是否正确 1B][置信度 4B float]
        let postureTypeRaw = data[0]
        let isCorrect = data[1] == 1
        let confidence = data.subdata(in: 2..<6).withUnsafeBytes { $0.load(as: Float.self) }
        
        let postureType: String
        switch postureTypeRaw {
        case 0: postureType = "correct"
        case 1: postureType = "head_forward"
        case 2: postureType = "slouch"
        case 3: postureType = "lean_left"
        case 4: postureType = "lean_right"
        default: postureType = "unknown"
        }
        
        let postureData = PostureData(
            postureType: postureType,
            isCorrect: isCorrect,
            confidence: confidence,
            timestamp: Date()
        )
        
        latestPosture = postureData
        postureDataSubject.send(postureData)
    }
}

// MARK: - 反馈类型

enum FeedbackType: UInt8 {
    case vibrate = 0x01      // 震动
    case vibrateLong = 0x02  // 长震动
    case beep = 0x10         // 蜂鸣
    case silence = 0x00      // 停止
}
