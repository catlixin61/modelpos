// 应用配置

import Foundation

/// 应用配置
enum AppConfig {
    // MARK: - API 配置
    
    /// API 基础 URL
    static let apiBaseURL: String = {
        #if DEBUG
        return "http://192.168.50.61:8000/api/v1"
        #else
        return "https://api.modelpos.com/api/v1"
        #endif
    }()
    
    /// API 超时时间
    static let apiTimeout: TimeInterval = 30
    
    // MARK: - 蓝牙配置
    
    /// 探测器服务 UUID
    static let detectorServiceUUID = "12345678-1234-1234-1234-123456789ABC"
    
    /// 姿态数据特征 UUID
    static let postureCharUUID = "12345678-1234-1234-1234-123456789ABD"
    
    /// 设置特征 UUID
    static let settingsCharUUID = "12345678-1234-1234-1234-123456789ABE"
    
    /// 蓝牙扫描超时时间
    static let bleScanTimeout: TimeInterval = 15
    
    // MARK: - 姿态配置
    
    /// 姿态类型定义
    static let postureTypes: [String: PostureInfo] = [
        "correct": PostureInfo(name: "正确姿态", isCorrect: true, color: .green),
        "head_forward": PostureInfo(name: "头部前倾", isCorrect: false, color: .orange),
        "slouch": PostureInfo(name: "驼背", isCorrect: false, color: .red),
        "lean_left": PostureInfo(name: "左倾", isCorrect: false, color: .yellow),
        "lean_right": PostureInfo(name: "右倾", isCorrect: false, color: .yellow),
    ]
    
    // MARK: - 缓存配置
    
    /// 日志同步阈值：本地累积多少条后自动同步
    static let logSyncThreshold = 50
    
    /// 日志同步间隔（秒）
    static let logSyncInterval: TimeInterval = 300  // 5分钟
}

/// 姿态信息
struct PostureInfo {
    let name: String
    let isCorrect: Bool
    let color: ColorType
    
    enum ColorType {
        case green, orange, red, yellow
    }
}
