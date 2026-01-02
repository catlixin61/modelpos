---
trigger: always_on
---

# 北岛 AI 姿态矫正器

## 技术栈

- Backend: Python 3.11, FastAPI, PostgreSQL, SQLAlchemy 2.0 (异步)
- iOS: SwiftUI, Combine, CoreBluetooth, SwiftData, iOS 17+
- Detector: ESP32-S3, Arduino, PlatformIO, NimBLE, TFLite Micro
- Feedbacker: ESP32-C3, Arduino, PlatformIO, NimBLE

## 目录

- `/backend` - Python 后台
- `/ios` - iOS 客户端
- `/detector` - ESP32-S3 探测器
- `/feedbacker` - ESP32-C3 反馈器

## 通信

- Detector→Feedbacker: BLE Extended Advertising
- iOS↔Detector: BLE GATT
- iOS↔Backend: HTTP REST API

## 规范

- 中文注释，英文代码
- Python: async/await, TypeAlias
- Swift: MVVM, Combine
- ESP32: NimBLE, 低功耗优先

详细规范见 `.cursor/rules/`
