# 北岛 AI 姿态矫正器 - iOS 客户端

## 技术栈

- **SwiftUI** - 声明式 UI 框架
- **Combine** - 响应式编程
- **CoreBluetooth** - 蓝牙 LE 通信
- **SwiftData** - 本地数据持久化
- **iOS 17+** - 最低支持版本

## 项目结构

```
ios/
├── ModelPos.xcodeproj/        # Xcode 项目文件
└── ModelPos/
    ├── ModelPosApp.swift      # 应用入口
    ├── Info.plist             # 应用配置
    ├── App/                   # 应用层
    │   ├── AppState.swift     # 全局状态管理
    │   ├── AppConfig.swift    # 配置常量
    │   └── TokenStorage.swift # Token 安全存储
    ├── Models/                # 数据模型
    │   ├── APIModels.swift    # API 数据模型
    │   └── CachedModels.swift # SwiftData 缓存模型
    ├── Services/              # 服务层
    │   ├── APIClient.swift    # HTTP API 客户端
    │   ├── BluetoothService.swift    # 蓝牙服务
    │   └── PostureMonitorService.swift # 姿态监控服务
    ├── Views/                 # 视图层
    │   ├── RootView.swift     # 根视图
    │   ├── Auth/              # 认证相关视图
    │   │   └── AuthNavigationView.swift
    │   ├── Main/              # 主界面视图
    │   │   ├── MainTabView.swift
    │   │   ├── HomeView.swift      # 首页-监控
    │   │   ├── StatsView.swift     # 统计
    │   │   ├── DevicesView.swift   # 设备管理
    │   │   └── ProfileView.swift   # 个人中心
    │   └── Components/        # 通用组件
    │       └── CommonComponents.swift
    ├── Extensions/            # 扩展
    │   └── Extensions.swift
    └── Resources/             # 资源文件
        └── Assets.xcassets/
```

## 功能模块

### 1. 用户认证

- 手机号 + 密码登录
- 用户注册
- Token 自动刷新
- Keychain 安全存储

### 2. 姿态监控

- 实时姿态显示（正确/不良）
- 监控时长统计
- 正确率计算
- 姿态历史记录

### 3. 统计分析

- 每日统计
- 周统计图表
- 正确率趋势

### 4. 设备管理

- 蓝牙扫描附近设备
- 设备绑定/解绑
- 连接状态显示
- 设备在线状态

### 5. 个人中心

- 用户信息编辑
- 设置选项
- 退出登录

## 蓝牙通信

### 服务 UUID

- 探测器服务: `12345678-1234-1234-1234-123456789ABC`

### 特征 UUID

- 姿态数据: `12345678-1234-1234-1234-123456789ABD`
- 设置命令: `12345678-1234-1234-1234-123456789ABE`

### 数据格式

**姿态数据 (6 bytes):**

| 字节 | 描述 |
|------|------|
| 0 | 姿态类型 (0=正确, 1=头前倾, 2=驼背, 3=左倾, 4=右倾) |
| 1 | 是否正确 (0/1) |
| 2-5 | 置信度 (float32) |

## 开发说明

### 运行项目

1. 使用 Xcode 15+ 打开 `ModelPos.xcodeproj`
2. 选择目标设备或模拟器
3. 按 `Cmd + R` 运行

### 调试模式

在 Debug 模式下，API 默认连接 `http://127.0.0.1:8000`。
如需更改，请修改 `AppConfig.swift` 中的 `apiBaseURL`。

### 真机调试蓝牙

蓝牙功能仅在真机上可用。请确保：

1. 设备已开启蓝牙
2. 应用已授权蓝牙权限
3. 探测器设备已开机并处于广播状态

## API 接口

iOS 客户端使用以下 API 端点：

### 认证

- `POST /api/v1/auth/login` - 登录
- `POST /api/v1/auth/register` - 注册
- `POST /api/v1/auth/refresh` - 刷新 Token

### 用户

- `GET /api/v1/users/me` - 获取当前用户
- `PUT /api/v1/users/me` - 更新用户信息
- `GET /api/v1/users/me/devices` - 获取我的设备
- `POST /api/v1/users/me/devices` - 绑定设备
- `DELETE /api/v1/users/me/devices/{id}` - 解绑设备

### 姿态数据

- `POST /api/v1/postures/logs` - 上传姿态日志
- `GET /api/v1/postures/stats` - 获取每日统计
- `GET /api/v1/postures/weekly` - 获取周统计

## 设计规范

### 配色方案

- 主色: `#667eea` (紫蓝渐变起点)
- 辅色: `#764ba2` (紫蓝渐变终点)
- 背景: `#0d1117` (深灰黑)
- 卡片: `#161b22` (暗灰)
- 成功: `#10b981` (绿)
- 警告: `#f59e0b` (橙)
- 错误: `#ef4444` (红)

### 圆角规范

- 大卡片: 24px
- 中卡片: 20px
- 按钮: 16px
- 输入框: 14px
- 小组件: 12px
