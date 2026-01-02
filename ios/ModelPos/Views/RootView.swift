// 根视图 - 管理导航和认证状态

import SwiftUI

/// 根视图
struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isLoggedIn {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                AuthNavigationView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isLoggedIn)
        .overlay(alignment: .top) {
            // 全局错误提示
            if let errorMessage = appState.errorMessage {
                ErrorBanner(message: errorMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: appState.errorMessage != nil)
    }
}

/// 错误横幅
struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.gradient)
            )
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
