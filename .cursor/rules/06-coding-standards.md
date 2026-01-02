# 代码规范

## 通用规范

- 中文注释，英文代码
- 使用有意义的变量/函数命名
- 每个文件不超过 300 行

## Python (Backend)

- Python 3.11+，使用 TypeAlias、| 替代 Union
- async/await 异步编程
- Pydantic 数据校验
- RESTful API 设计

## Swift (iOS)

- SwiftUI 声明式 UI
- Combine 处理异步数据流
- SwiftData 本地存储
- MVVM 架构

## C++ (ESP32)

- Arduino + PlatformIO
- 模块化设计，单一职责
- 紧凑二进制协议
- 低功耗优先

## Git 规范

- feat: 新功能
- fix: 修复
- docs: 文档
- refactor: 重构

## 目录结构

```
/backend     - Python FastAPI
/ios         - SwiftUI App
/detector    - ESP32-S3 探测器
/feedbacker  - ESP32-C3 反馈器
```
