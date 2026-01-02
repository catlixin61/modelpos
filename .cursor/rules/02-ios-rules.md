# iOS 客户端开发规范

## 技术栈要求

| 组件 | 框架/库 | 说明 |
|------|---------|------|
| UI框架 | SwiftUI | 声明式界面开发 |
| 响应式 | Combine | 处理蓝牙数据流 |
| 蓝牙 | CoreBluetooth | BLE 5.0 支持 |
| 存储 | SwiftData | 本地姿态历史缓存 |
| 图表 | Swift Charts | 周/月统计曲线 |
| 最低版本 | iOS 17.0 | SwiftData 要求 |

## 目录结构

```
/ios/PostureCorrector
├── App/
│   ├── PostureCorrectorApp.swift   # 应用入口
│   └── ContentView.swift
├── Core/
│   ├── Bluetooth/
│   │   ├── BLEManager.swift         # 蓝牙管理器
│   │   ├── BLEScanner.swift         # 扫描模式 (Extended Adv)
│   │   ├── BLEConnector.swift       # GATT 连接模式
│   │   └── BLEProtocol.swift        # 协议定义
│   ├── Network/
│   │   ├── APIClient.swift          # HTTP 客户端
│   │   └── Endpoints.swift
│   └── Storage/
│       ├── PostureStore.swift       # SwiftData 存储
│       └── Models/
├── Features/
│   ├── Home/                         # 首页 - 实时状态
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   ├── Statistics/                   # 统计 - 图表展示
│   │   ├── StatisticsView.swift
│   │   └── ChartBuilder.swift
│   ├── Devices/                      # 设备管理
│   │   ├── DeviceListView.swift
│   │   ├── DevicePairingView.swift
│   │   └── DeviceConfigView.swift
│   └── Settings/                     # 设置
│       └── SettingsView.swift
├── Shared/
│   ├── Components/                   # 可复用组件
│   ├── Extensions/
│   └── Constants.swift
└── Resources/
```

## 蓝牙通信规范

### 模式 A: 扫描模式 (无连接)

用于首页实时状态刷新

```swift
class BLEScanner: NSObject, ObservableObject {
    @Published var latestPostureData: PostureData?
    
    /// 扫描 Extended Advertising
    func startScanning() {
        centralManager.scanForPeripherals(
            withServices: [POSTURE_SERVICE_UUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
    
    /// 解析广播包中的姿态数据
    func parseAdvertisementData(_ data: [String: Any]) -> PostureData? {
        guard let serviceData = data[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
              let postureData = serviceData[POSTURE_SERVICE_UUID]
        else { return nil }
        return PostureData(from: postureData)
    }
}
```

### 模式 B: 连接模式 (GATT)

用于拉取历史日志

```swift
class BLEConnector: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    
    /// 连接设备并拉取日志
    func fetchLogs(from peripheral: CBPeripheral) async throws -> [PostureLog] {
        // 1. 建立 GATT 连接
        // 2. 发现服务和特征
        // 3. 读取 LittleFS 存储的历史日志
        // 4. 断开连接
    }
    
    /// 写入配置到探测器
    func writeConfig(_ config: DeviceConfig, to peripheral: CBPeripheral) async throws {
        // 配置写入逻辑
    }
}
```

### BLE UUID 定义

```swift
struct BLEConstants {
    // 服务 UUID
    static let POSTURE_SERVICE_UUID = CBUUID(string: "0000AAAA-0000-1000-8000-00805F9B34FB")
    
    // 特征 UUID
    static let POSTURE_DATA_CHAR = CBUUID(string: "0000AAAB-0000-1000-8000-00805F9B34FB")
    static let LOG_READ_CHAR = CBUUID(string: "0000AAAC-0000-1000-8000-00805F9B34FB")
    static let CONFIG_WRITE_CHAR = CBUUID(string: "0000AAAD-0000-1000-8000-00805F9B34FB")
}
```

## 数据模型规范

### SwiftData 模型

```swift
import SwiftData

@Model
class PostureLog {
    var id: UUID
    var timestamp: Date
    var postureType: PostureType
    var duration: TimeInterval
    var deviceId: String
    var synced: Bool
    
    init(timestamp: Date, postureType: PostureType, duration: TimeInterval, deviceId: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.postureType = postureType
        self.duration = duration
        self.deviceId = deviceId
        self.synced = false
    }
}

enum PostureType: String, Codable {
    case normal = "normal"
    case hunched = "hunched"       // 驼背
    case leanLeft = "lean_left"    // 左倾
    case leanRight = "lean_right"  // 右倾
}
```

## UI 组件规范

### 首页实时状态卡片

```swift
struct PostureStatusCard: View {
    let status: PostureStatus
    
    var body: some View {
        VStack {
            Image(systemName: status.iconName)
                .font(.system(size: 60))
                .foregroundColor(status.color)
            
            Text(status.title)
                .font(.headline)
            
            Text(status.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }
}
```

### 统计图表

```swift
import Charts

struct WeeklyChart: View {
    let data: [DailyPostureData]
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("日期", item.date, unit: .day),
                y: .value("驼背次数", item.hunchCount)
            )
            .foregroundStyle(.red.gradient)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
    }
}
```

## Combine 数据流模式

```swift
class HomeViewModel: ObservableObject {
    @Published var postureStatus: PostureStatus = .unknown
    @Published var todayStats: DailyStats?
    
    private var cancellables = Set<AnyCancellable>()
    private let bleScanner: BLEScanner
    
    init(bleScanner: BLEScanner) {
        self.bleScanner = bleScanner
        setupBindings()
    }
    
    private func setupBindings() {
        bleScanner.$latestPostureData
            .compactMap { $0 }
            .map { PostureStatus(from: $0) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$postureStatus)
    }
}
```

## 网络请求规范

```swift
class APIClient {
    static let shared = APIClient()
    private let baseURL = URL(string: "https://api.beidao-posture.com/api/v1")!
    
    /// 上传日志到后台
    func uploadLogs(_ logs: [PostureLog]) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("postures/logs"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(TokenManager.shared.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(logs)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.uploadFailed
        }
    }
}
```

## 设备配对流程

1. 扫描发现附近探测器
2. 用户选择探测器进行配对
3. 建立 GATT 连接
4. 写入用户 ID 和配置
5. 可选：关联反馈器 MAC 地址
6. 断开连接，完成配对
