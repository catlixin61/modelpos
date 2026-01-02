// 应用全局状态管理

import SwiftUI
import Combine

/// 应用全局状态
@MainActor
final class AppState: ObservableObject {
    // MARK: - 认证状态
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: UserInfo?
    @Published var accessToken: String?
    @Published var refreshToken: String?
    
    // MARK: - 设备状态
    @Published var connectedDevice: DeviceInfo?
    @Published var isDeviceConnected: Bool = false
    
    // MARK: - 加载状态
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let tokenStorage = TokenStorage()
    
    init() {
        loadStoredAuth()
    }
    
    // MARK: - 认证方法
    
    /// 从本地加载认证信息
    private func loadStoredAuth() {
        if let accessToken = tokenStorage.getAccessToken(),
           let refreshToken = tokenStorage.getRefreshToken() {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.isLoggedIn = true
            
            // 获取用户信息
            Task {
                await fetchCurrentUser()
            }
        }
    }
    
    /// 保存认证信息
    func saveAuth(tokens: TokenResponse, user: UserInfo? = nil) {
        self.accessToken = tokens.accessToken
        self.refreshToken = tokens.refreshToken
        self.isLoggedIn = true
        self.currentUser = user
        
        tokenStorage.saveTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken
        )
    }
    
    /// 登出
    func logout() {
        self.accessToken = nil
        self.refreshToken = nil
        self.isLoggedIn = false
        self.currentUser = nil
        self.connectedDevice = nil
        self.isDeviceConnected = false
        
        tokenStorage.clearTokens()
    }
    
    /// 获取当前用户信息
    func fetchCurrentUser() async {
        guard accessToken != nil else { return }
        
        do {
            let user = try await APIClient.shared.getCurrentUser()
            self.currentUser = user
        } catch {
            // Token 可能过期，尝试刷新
            if case APIError.unauthorized = error {
                await refreshAccessToken()
            }
        }
    }
    
    /// 刷新访问令牌
    func refreshAccessToken() async {
        guard let refreshToken = refreshToken else {
            logout()
            return
        }
        
        do {
            let tokens = try await APIClient.shared.refreshToken(refreshToken: refreshToken)
            saveAuth(tokens: tokens)
            await fetchCurrentUser()
        } catch {
            logout()
        }
    }
    
    // MARK: - 错误处理
    
    func showError(_ message: String) {
        errorMessage = message
        // 3秒后自动清除
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.errorMessage = nil
        }
    }
}
