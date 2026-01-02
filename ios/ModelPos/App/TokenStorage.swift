// Token 本地存储管理

import Foundation
import Security

/// Token 存储类 - 使用 Keychain 安全存储
final class TokenStorage {
    private let accessTokenKey = "com.modelpos.accessToken"
    private let refreshTokenKey = "com.modelpos.refreshToken"
    
    // MARK: - 保存 Token
    
    func saveTokens(accessToken: String, refreshToken: String) {
        saveToKeychain(key: accessTokenKey, value: accessToken)
        saveToKeychain(key: refreshTokenKey, value: refreshToken)
    }
    
    // MARK: - 获取 Token
    
    func getAccessToken() -> String? {
        return getFromKeychain(key: accessTokenKey)
    }
    
    func getRefreshToken() -> String? {
        return getFromKeychain(key: refreshTokenKey)
    }
    
    // MARK: - 清除 Token
    
    func clearTokens() {
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
    }
    
    // MARK: - Keychain 操作
    
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        // 先删除旧的
        deleteFromKeychain(key: key)
        
        // 添加新的
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
