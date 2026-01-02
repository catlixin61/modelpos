// API 客户端

import Foundation
import Combine

/// API 错误类型
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String?)
    case unauthorized
    case forbidden
    case notFound
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return message ?? "服务器错误 (\(code))"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .forbidden:
            return "没有权限访问"
        case .notFound:
            return "资源不存在"
        case .unknown:
            return "未知错误"
        }
    }
}

/// API 客户端
actor APIClient {
    static let shared = APIClient()
    
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private var accessToken: String?
    
    private init() {
        self.baseURL = AppConfig.apiBaseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.apiTimeout
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // 尝试多种日期格式
            let formatters = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd"
            ]
            
            for format in formatters {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析日期: \(dateString)"
            )
        }
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Token 管理
    
    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }
    
    // MARK: - 通用请求方法
    
    private func request<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard var urlComponents = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        if let queryItems = queryItems {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
                if let responseData = apiResponse.data {
                    return responseData
                }
                throw APIError.unknown
            } catch {
                // 尝试直接解析
                return try decoder.decode(T.self, from: data)
            }
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
    
    // MARK: - 认证 API
    
    /// 用户登录
    func login(phone: String, password: String) async throws -> TokenResponse {
        let body = LoginRequest(phone: phone, password: password)
        return try await request("POST", path: "/auth/login", body: body, requiresAuth: false)
    }
    
    /// 用户注册
    func register(phone: String, password: String, nickname: String) async throws -> TokenResponse {
        let body = RegisterRequest(phone: phone, password: password, nickname: nickname)
        return try await request("POST", path: "/auth/register", body: body, requiresAuth: false)
    }
    
    /// 刷新 Token
    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        let body = RefreshTokenRequest(refreshToken: refreshToken)
        return try await request("POST", path: "/auth/refresh", body: body, requiresAuth: false)
    }
    
    // MARK: - 用户 API
    
    /// 获取当前用户信息
    func getCurrentUser() async throws -> UserInfo {
        return try await request("GET", path: "/users/me")
    }
    
    /// 更新用户信息
    func updateUser(nickname: String?, avatarUrl: String?) async throws -> UserInfo {
        let body = UserUpdateRequest(nickname: nickname, avatarUrl: avatarUrl)
        return try await request("PUT", path: "/users/me", body: body)
    }
    
    // MARK: - 设备 API
    
    /// 获取我的设备列表
    func getMyDevices() async throws -> [DeviceInfo] {
        return try await request("GET", path: "/users/me/devices")
    }
    
    /// 绑定设备
    func bindDevice(macAddress: String, deviceType: DeviceType, name: String) async throws -> DeviceInfo {
        let body = DeviceCreateRequest(
            macAddress: macAddress,
            deviceType: deviceType,
            name: name,
            firmwareVersion: "1.0.0"
        )
        return try await request("POST", path: "/users/me/devices", body: body)
    }
    
    /// 解绑设备
    func unbindDevice(deviceId: Int) async throws {
        let _: APIResponse<String?> = try await request("DELETE", path: "/users/me/devices/\(deviceId)")
    }
    
    // MARK: - 姿态数据 API
    
    /// 上传姿态日志
    func uploadPostureLogs(_ logs: [PostureLogCreate]) async throws {
        let _: APIResponse<String?> = try await request("POST", path: "/postures/logs", body: logs)
    }
    
    /// 获取今日统计
    func getTodayStats() async throws -> PostureStats {
        return try await request("GET", path: "/postures/stats")
    }
    
    /// 获取指定日期统计
    func getStats(date: Date) async throws -> PostureStats {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        return try await request(
            "GET",
            path: "/postures/stats",
            queryItems: [URLQueryItem(name: "target_date", value: dateString)]
        )
    }
    
    /// 获取周统计
    func getWeeklyStats(startDate: Date? = nil) async throws -> WeeklyStats {
        var queryItems: [URLQueryItem]? = nil
        
        if let startDate = startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            queryItems = [URLQueryItem(name: "start_date", value: formatter.string(from: startDate))]
        }
        
        return try await request("GET", path: "/postures/weekly", queryItems: queryItems)
    }
}
