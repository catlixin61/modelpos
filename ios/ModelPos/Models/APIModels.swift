// API 数据模型

import Foundation

// MARK: - 通用响应模型

/// API 统一响应格式
struct APIResponse<T: Decodable>: Decodable {
    let code: Int?
    let message: String?
    let data: T?
    
    var isSuccess: Bool {
        return code == nil || code == 0 || code == 200
    }
}

/// 分页响应
struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
    
    private enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize = "page_size"
        case totalPages = "total_pages"
    }
}

// MARK: - 认证模型

/// 登录请求
struct LoginRequest: Codable {
    let phone: String
    let password: String
}

/// 注册请求
struct RegisterRequest: Codable {
    let phone: String
    let password: String
    let nickname: String
}

/// Token 响应
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

/// 刷新 Token 请求
struct RefreshTokenRequest: Codable {
    let refreshToken: String
    
    private enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// MARK: - 用户模型

/// 用户信息
struct UserInfo: Codable, Identifiable {
    let id: Int
    let phone: String
    let nickname: String
    let avatarUrl: String?
    let isAdmin: Bool
    let isActive: Bool
    let createdAt: Date
    let lastLoginAt: Date?
    let deviceCount: Int
    
    private enum CodingKeys: String, CodingKey {
        case id, phone, nickname
        case avatarUrl = "avatar_url"
        case isAdmin = "is_admin"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
        case deviceCount = "device_count"
    }
}

/// 用户更新请求
struct UserUpdateRequest: Codable {
    let nickname: String?
    let avatarUrl: String?
    
    private enum CodingKeys: String, CodingKey {
        case nickname
        case avatarUrl = "avatar_url"
    }
}

// MARK: - 设备模型

/// 设备类型
enum DeviceType: String, Codable {
    case detector = "detector"       // 探测器
    case feedbacker = "feedbacker"   // 反馈器
    
    var displayName: String {
        switch self {
        case .detector: return "探测器"
        case .feedbacker: return "反馈器"
        }
    }
    
    var icon: String {
        switch self {
        case .detector: return "sensor"
        case .feedbacker: return "waveform.badge.plus"
        }
    }
}

/// 设备信息
struct DeviceInfo: Codable, Identifiable {
    let id: Int
    let macAddress: String
    let deviceType: DeviceType
    let name: String
    let firmwareVersion: String
    let userId: Int?
    let pairedDeviceId: Int?
    let isOnline: Bool
    let lastSeenAt: Date?
    let createdAt: Date
    let userPhone: String?
    let pairedDeviceMac: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, name
        case macAddress = "mac_address"
        case deviceType = "device_type"
        case firmwareVersion = "firmware_version"
        case userId = "user_id"
        case pairedDeviceId = "paired_device_id"
        case isOnline = "is_online"
        case lastSeenAt = "last_seen_at"
        case createdAt = "created_at"
        case userPhone = "user_phone"
        case pairedDeviceMac = "paired_device_mac"
    }
}

/// 设备创建请求
struct DeviceCreateRequest: Codable {
    let macAddress: String
    let deviceType: DeviceType
    let name: String
    let firmwareVersion: String
    
    private enum CodingKeys: String, CodingKey {
        case name
        case macAddress = "mac_address"
        case deviceType = "device_type"
        case firmwareVersion = "firmware_version"
    }
}

// MARK: - 姿态数据模型

/// 姿态日志创建
struct PostureLogCreate: Codable {
    let deviceId: Int
    let postureType: String
    let duration: Int
    let isCorrect: Bool
    let recordedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case duration
        case deviceId = "device_id"
        case postureType = "posture_type"
        case isCorrect = "is_correct"
        case recordedAt = "recorded_at"
    }
}

/// 姿态日志响应
struct PostureLogResponse: Codable, Identifiable {
    let id: Int
    let deviceId: Int
    let userId: Int
    let postureType: String
    let duration: Int
    let isCorrect: Bool
    let recordedAt: Date
    let createdAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, duration
        case deviceId = "device_id"
        case userId = "user_id"
        case postureType = "posture_type"
        case isCorrect = "is_correct"
        case recordedAt = "recorded_at"
        case createdAt = "created_at"
    }
}

/// 每日姿态统计
struct PostureStats: Codable {
    let date: Date
    let totalDuration: Int     // 总时长(秒)
    let correctDuration: Int   // 正确姿态时长
    let incorrectDuration: Int // 不良姿态时长
    let correctRate: Double    // 正确率 (0-1)
    let postureBreakdown: [String: Int]? // 各姿态时长
    
    private enum CodingKeys: String, CodingKey {
        case date
        case totalDuration = "total_duration"
        case correctDuration = "correct_duration"
        case incorrectDuration = "incorrect_duration"
        case correctRate = "correct_rate"
        case postureBreakdown = "posture_breakdown"
    }
    
    /// 正确率百分比
    var correctPercentage: Int {
        return Int(correctRate * 100)
    }
    
    /// 格式化的总时长
    var formattedTotalDuration: String {
        return formatDuration(totalDuration)
    }
    
    /// 格式化的正确时长
    var formattedCorrectDuration: String {
        return formatDuration(correctDuration)
    }
    
    /// 格式化的不良时长
    var formattedIncorrectDuration: String {
        return formatDuration(incorrectDuration)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "\(seconds)秒"
        }
    }
}

/// 周统计
struct WeeklyStats: Codable {
    let startDate: Date
    let endDate: Date
    let dailyStats: [PostureStats]
    let totalCorrectDuration: Int
    let totalIncorrectDuration: Int
    let averageCorrectRate: Double
    
    private enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case dailyStats = "daily_stats"
        case totalCorrectDuration = "total_correct_duration"
        case totalIncorrectDuration = "total_incorrect_duration"
        case averageCorrectRate = "average_correct_rate"
    }
    
    var averagePercentage: Int {
        return Int(averageCorrectRate * 100)
    }
}
