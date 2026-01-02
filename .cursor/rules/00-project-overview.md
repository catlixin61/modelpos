# 北岛 AI 姿态矫正器

## 端别划分

| 端别 | 目录 | 技术栈 | 职责 |
|------|------|--------|------|
| Backend | `/backend` | Python 3.11, FastAPI, PostgreSQL | 用户管理、硬件注册、数据同步 |
| iOS | `/ios` | SwiftUI, CoreBluetooth, SwiftData | 统计展示、设备配置、日志拉取 |
| Detector | `/detector` | ESP32-S3, Arduino, PlatformIO | AI姿态检测、广播触发、日志存储 |
| Feedbacker | `/feedbacker` | ESP32-C3, Arduino, PlatformIO | 被动扫描、接收指令、马达控制 |

## 核心通信协议

### BLE 通信矩阵

| 发送方 | 接收方 | 模式 | 用途 |
|--------|--------|------|------|
| Detector | Feedbacker | BLE Extended Advertising | 驼背触发信号 |
| Detector | iOS | BLE GATT Connection | 日志数据拉取 |
| iOS | Detector | BLE GATT Write | 配置参数下发 |

### 设计原则

- **独立运行**: Detector + Feedbacker 可脱离手机独立工作
- **按需连接**: iOS 仅在主动打开 App 时建立 GATT 连接
- **单向触发**: Detector → Feedbacker 采用无连接广播模式
