// 设备管理视图

import SwiftUI

/// 设备管理视图
struct DevicesView: View {
    @State private var devices: [DeviceInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddDevice = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d1117")
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if devices.isEmpty {
                    EmptyDevicesView(onAdd: { showAddDevice = true })
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(devices) { device in
                                DeviceCard(device: device, onUnbind: {
                                    await unbindDevice(device)
                                })
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("我的设备")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddDevice = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color(hex: "667eea"))
                    }
                }
            }
            .sheet(isPresented: $showAddDevice) {
                DeviceScanSheet()
            }
            .task {
                await loadDevices()
            }
            .refreshable {
                await loadDevices()
            }
        }
    }
    
    private func loadDevices() async {
        isLoading = true
        errorMessage = nil
        
        do {
            devices = try await APIClient.shared.getMyDevices()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func unbindDevice(_ device: DeviceInfo) async {
        do {
            try await APIClient.shared.unbindDevice(deviceId: device.id)
            devices.removeAll { $0.id == device.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// 空设备视图
struct EmptyDevicesView: View {
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundStyle(Color(hex: "667eea").opacity(0.5))
            
            VStack(spacing: 8) {
                Text("暂无设备")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("点击下方按钮添加您的第一个设备")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加设备")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "667eea").opacity(0.4), radius: 15, y: 8)
            }
        }
        .padding()
    }
}

/// 设备卡片
struct DeviceCard: View {
    let device: DeviceInfo
    let onUnbind: () async -> Void
    
    @State private var showUnbindAlert = false
    @StateObject private var bluetoothService = BluetoothService.shared
    
    var isConnected: Bool {
        bluetoothService.connectedDevice?.macAddress == device.macAddress
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 顶部信息
            HStack(spacing: 16) {
                // 设备图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea").opacity(0.2), Color(hex: "764ba2").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: device.deviceType.icon)
                        .font(.title2)
                        .foregroundStyle(Color(hex: "667eea"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name.isEmpty ? device.deviceType.displayName : device.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(device.macAddress)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .fontDesign(.monospaced)
                }
                
                Spacer()
                
                // 状态指示
                VStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? .green : (device.isOnline ? .yellow : .gray))
                        .frame(width: 10, height: 10)
                    
                    Text(isConnected ? "已连接" : (device.isOnline ? "在线" : "离线"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 底部信息
            HStack {
                // 设备类型
                Label {
                    Text(device.deviceType.displayName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                } icon: {
                    Image(systemName: device.deviceType == .detector ? "sensor" : "waveform.badge.plus")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "667eea"))
                }
                
                Spacer()
                
                // 固件版本
                Label {
                    Text("v\(device.firmwareVersion)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                } icon: {
                    Image(systemName: "gear")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                // 解绑按钮
                Button {
                    showUnbindAlert = true
                } label: {
                    Text("解绑")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "161b22"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isConnected ? Color(hex: "667eea").opacity(0.5) : Color.white.opacity(0.05),
                            lineWidth: 1
                        )
                )
        )
        .alert("解绑设备", isPresented: $showUnbindAlert) {
            Button("取消", role: .cancel) {}
            Button("确认解绑", role: .destructive) {
                Task { await onUnbind() }
            }
        } message: {
            Text("确定要解绑这个设备吗？解绑后需要重新扫描添加。")
        }
    }
}

/// 设备扫描弹窗
struct DeviceScanSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var bluetoothService = BluetoothService.shared
    
    @State private var isBinding = false
    @State private var bindError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d1117")
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 蓝牙状态
                    BluetoothStatusView(state: bluetoothService.state)
                    
                    if bluetoothService.state == .scanning {
                        // 扫描中
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("正在扫描设备...")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.vertical, 40)
                    } else if bluetoothService.discoveredDevices.isEmpty {
                        // 无设备
                        VStack(spacing: 16) {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                .font(.system(size: 50))
                                .foregroundStyle(.white.opacity(0.3))
                            
                            Text("未发现设备")
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text("请确保设备已开启并在附近")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.vertical, 40)
                    }
                    
                    // 设备列表
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(bluetoothService.discoveredDevices) { device in
                                DiscoveredDeviceRow(
                                    device: device,
                                    isConnecting: bluetoothService.state == .connecting,
                                    onConnect: {
                                        bluetoothService.connect(to: device)
                                    },
                                    onBind: {
                                        await bindDevice(device)
                                    }
                                )
                            }
                        }
                    }
                    
                    // 扫描按钮
                    if bluetoothService.state != .scanning {
                        Button {
                            bluetoothService.startScan()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("重新扫描")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "667eea"))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("添加设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                bluetoothService.start()
                bluetoothService.startScan()
            }
            .onDisappear {
                bluetoothService.stopScan()
            }
            .alert("绑定失败", isPresented: .constant(bindError != nil)) {
                Button("确定") {
                    bindError = nil
                }
            } message: {
                Text(bindError ?? "")
            }
        }
    }
    
    private func bindDevice(_ device: DiscoveredDevice) async {
        guard let macAddress = device.macAddress,
              let deviceType = device.deviceType else {
            bindError = "无法获取设备信息"
            return
        }
        
        isBinding = true
        
        do {
            _ = try await APIClient.shared.bindDevice(
                macAddress: macAddress,
                deviceType: deviceType,
                name: device.name
            )
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            bindError = error.localizedDescription
        }
        
        isBinding = false
    }
}

/// 蓝牙状态视图
struct BluetoothStatusView: View {
    let state: BluetoothState
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
        )
        .padding(.horizontal)
    }
    
    private var iconName: String {
        switch state {
        case .poweredOn, .connected: return "bluetooth"
        case .poweredOff: return "bluetooth.slash"
        case .scanning: return "dot.radiowaves.left.and.right"
        case .connecting: return "antenna.radiowaves.left.and.right"
        default: return "questionmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch state {
        case .poweredOn, .connected: return .green
        case .poweredOff: return .red
        case .scanning, .connecting: return Color(hex: "667eea")
        default: return .gray
        }
    }
    
    private var statusText: String {
        switch state {
        case .unknown: return "蓝牙状态未知"
        case .poweredOff: return "请打开蓝牙"
        case .poweredOn: return "蓝牙已开启"
        case .unauthorized: return "请授权蓝牙权限"
        case .unsupported: return "设备不支持蓝牙"
        case .scanning: return "正在扫描..."
        case .connecting: return "正在连接..."
        case .connected: return "已连接"
        case .disconnected: return "已断开"
        }
    }
    
    private var backgroundColor: Color {
        switch state {
        case .poweredOff, .unauthorized, .unsupported:
            return .red.opacity(0.15)
        case .connected:
            return .green.opacity(0.15)
        default:
            return Color(hex: "161b22")
        }
    }
}

/// 发现的设备行
struct DiscoveredDeviceRow: View {
    let device: DiscoveredDevice
    let isConnecting: Bool
    let onConnect: () -> Void
    let onBind: () async -> Void
    
    @State private var isBinding = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 设备图标
            ZStack {
                Circle()
                    .fill(Color(hex: "667eea").opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: device.deviceType?.icon ?? "antenna.radiowaves.left.and.right")
                    .foregroundStyle(Color(hex: "667eea"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if let mac = device.macAddress {
                    Text(mac)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .fontDesign(.monospaced)
                }
            }
            
            Spacer()
            
            // 信号强度
            SignalStrengthView(rssi: device.rssi)
            
            // 绑定按钮
            Button {
                Task {
                    isBinding = true
                    await onBind()
                    isBinding = false
                }
            } label: {
                if isBinding {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("绑定")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .disabled(isBinding || isConnecting)
            .frame(width: 60, height: 32)
            .background(Color(hex: "667eea"))
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "161b22"))
        )
        .padding(.horizontal)
    }
}

/// 信号强度视图
struct SignalStrengthView: View {
    let rssi: Int
    
    private var signalLevel: Int {
        if rssi >= -50 { return 4 }
        if rssi >= -60 { return 3 }
        if rssi >= -70 { return 2 }
        return 1
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level <= signalLevel ? Color(hex: "667eea") : Color.white.opacity(0.2))
                    .frame(width: 4, height: CGFloat(level * 4 + 4))
            }
        }
    }
}

#Preview {
    DevicesView()
        .preferredColorScheme(.dark)
}
