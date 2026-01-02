// 认证导航视图

import SwiftUI

/// 认证导航视图
struct AuthNavigationView: View {
    @State private var showLogin = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 渐变背景
                LinearGradient(
                    colors: [
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e"),
                        Color(hex: "0f3460")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Logo 和标题
                    VStack(spacing: 16) {
                        // Logo
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: Color(hex: "667eea").opacity(0.5), radius: 20)
                            
                            Image(systemName: "figure.stand")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("北岛")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text("AI 姿态矫正器")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                    
                    // 登录/注册切换
                    if showLogin {
                        LoginView(showLogin: $showLogin)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading),
                                removal: .move(edge: .trailing)
                            ))
                    } else {
                        RegisterView(showLogin: $showLogin)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    }
                    
                    Spacer()
                }
            }
        }
        .animation(.spring(response: 0.4), value: showLogin)
    }
}

/// 登录视图
struct LoginView: View {
    @Binding var showLogin: Bool
    @EnvironmentObject var appState: AppState
    
    @State private var phone = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // 输入框
            VStack(spacing: 16) {
                CustomTextField(
                    placeholder: "手机号",
                    text: $phone,
                    icon: "phone.fill",
                    keyboardType: .phonePad
                )
                
                CustomSecureField(
                    placeholder: "密码",
                    text: $password,
                    icon: "lock.fill"
                )
            }
            .padding(.horizontal, 24)
            
            // 登录按钮
            Button(action: login) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("登录")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(hex: "667eea").opacity(0.4), radius: 15, y: 8)
            }
            .disabled(isLoading || phone.isEmpty || password.isEmpty)
            .padding(.horizontal, 24)
            
            // 切换到注册
            HStack {
                Text("还没有账号？")
                    .foregroundStyle(.white.opacity(0.6))
                
                Button("立即注册") {
                    showLogin = false
                }
                .foregroundStyle(Color(hex: "667eea"))
                .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .alert("登录失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func login() {
        guard !phone.isEmpty && !password.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                let tokens = try await APIClient.shared.login(phone: phone, password: password)
                await APIClient.shared.setAccessToken(tokens.accessToken)
                
                let user = try await APIClient.shared.getCurrentUser()
                
                await MainActor.run {
                    appState.saveAuth(tokens: tokens, user: user)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

/// 注册视图
struct RegisterView: View {
    @Binding var showLogin: Bool
    @EnvironmentObject var appState: AppState
    
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var nickname = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // 输入框
            VStack(spacing: 16) {
                CustomTextField(
                    placeholder: "昵称",
                    text: $nickname,
                    icon: "person.fill"
                )
                
                CustomTextField(
                    placeholder: "手机号",
                    text: $phone,
                    icon: "phone.fill",
                    keyboardType: .phonePad
                )
                
                CustomSecureField(
                    placeholder: "密码",
                    text: $password,
                    icon: "lock.fill"
                )
                
                CustomSecureField(
                    placeholder: "确认密码",
                    text: $confirmPassword,
                    icon: "lock.fill"
                )
            }
            .padding(.horizontal, 24)
            
            // 注册按钮
            Button(action: register) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("注册")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(hex: "667eea").opacity(0.4), radius: 15, y: 8)
            }
            .disabled(isLoading || !isFormValid)
            .padding(.horizontal, 24)
            
            // 切换到登录
            HStack {
                Text("已有账号？")
                    .foregroundStyle(.white.opacity(0.6))
                
                Button("立即登录") {
                    showLogin = true
                }
                .foregroundStyle(Color(hex: "667eea"))
                .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .alert("注册失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isFormValid: Bool {
        !phone.isEmpty && 
        !password.isEmpty && 
        password == confirmPassword && 
        password.count >= 6
    }
    
    private func register() {
        guard isFormValid else { return }
        
        isLoading = true
        
        Task {
            do {
                let finalNickname = nickname.isEmpty ? "用户" : nickname
                let tokens = try await APIClient.shared.register(
                    phone: phone,
                    password: password,
                    nickname: finalNickname
                )
                await APIClient.shared.setAccessToken(tokens.accessToken)
                
                let user = try await APIClient.shared.getCurrentUser()
                
                await MainActor.run {
                    appState.saveAuth(tokens: tokens, user: user)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    AuthNavigationView()
        .environmentObject(AppState())
}
