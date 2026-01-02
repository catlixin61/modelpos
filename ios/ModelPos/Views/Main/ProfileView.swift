// 个人中心视图

import SwiftUI

/// 个人中心视图
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogoutAlert = false
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d1117")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 用户信息卡片
                        UserInfoCard(
                            user: appState.currentUser,
                            onEdit: { showEditProfile = true }
                        )
                        
                        // 设置选项
                        SettingsSection()
                        
                        // 关于
                        AboutSection()
                        
                        // 退出登录
                        Button {
                            showLogoutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("退出登录")
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .alert("退出登录", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("确认退出", role: .destructive) {
                    appState.logout()
                }
            } message: {
                Text("确定要退出当前账号吗？")
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(user: appState.currentUser)
            }
        }
    }
}

/// 用户信息卡片
struct UserInfoCard: View {
    let user: UserInfo?
    let onEdit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Text(user?.nickname.prefix(1) ?? "用")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            // 用户名
            VStack(spacing: 4) {
                Text(user?.nickname ?? "用户")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text(user?.phone ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            // 统计
            HStack(spacing: 40) {
                UserStatItem(title: "设备", value: "\(user?.deviceCount ?? 0)")
                
                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.2))
                
                UserStatItem(title: "注册天数", value: daysSinceCreation)
            }
            
            // 编辑按钮
            Button(action: onEdit) {
                HStack {
                    Image(systemName: "pencil")
                    Text("编辑资料")
                }
                .font(.subheadline)
                .foregroundStyle(Color(hex: "667eea"))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .stroke(Color(hex: "667eea"), lineWidth: 1)
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "161b22"))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private var daysSinceCreation: String {
        guard let createdAt = user?.createdAt else { return "0" }
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        return "\(max(days, 1))"
    }
}

/// 用户统计项
struct UserStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color(hex: "667eea"))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

/// 设置分组
struct SettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "bell.fill",
                    iconColor: .orange,
                    title: "提醒设置",
                    destination: Text("提醒设置")
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                SettingsRow(
                    icon: "vibration.on",
                    iconColor: Color(hex: "667eea"),
                    title: "反馈设置",
                    destination: Text("反馈设置")
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                SettingsRow(
                    icon: "moon.fill",
                    iconColor: .purple,
                    title: "显示设置",
                    destination: Text("显示设置")
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "161b22"))
            )
            .padding(.horizontal)
        }
    }
}

/// 设置行
struct SettingsRow<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
                
                Text(title)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

/// 关于分组
struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关于")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                AboutRow(
                    icon: "info.circle.fill",
                    iconColor: .blue,
                    title: "关于我们"
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                AboutRow(
                    icon: "doc.text.fill",
                    iconColor: .gray,
                    title: "用户协议"
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                AboutRow(
                    icon: "hand.raised.fill",
                    iconColor: .green,
                    title: "隐私政策"
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "667eea").opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "number")
                            .foregroundStyle(Color(hex: "667eea"))
                    }
                    
                    Text("版本号")
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text("1.0.0")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "161b22"))
            )
            .padding(.horizontal)
        }
    }
}

/// 关于行
struct AboutRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    
    var body: some View {
        Button {
            // TODO: 实现导航
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
                
                Text(title)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

/// 编辑资料弹窗
struct EditProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    let user: UserInfo?
    
    @State private var nickname: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d1117")
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 头像
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
                        
                        Text(nickname.prefix(1).isEmpty ? "用" : String(nickname.prefix(1)))
                            .font(.system(size: 40))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        // 编辑图标
                        Circle()
                            .fill(Color(hex: "667eea"))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 35, y: 35)
                    }
                    .padding(.top, 20)
                    
                    // 昵称输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("昵称")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("输入昵称", text: $nickname)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "161b22"))
                            )
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // 保存按钮
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("保存")
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
                    }
                    .disabled(isSaving || nickname.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                nickname = user?.nickname ?? ""
            }
            .alert("保存失败", isPresented: .constant(errorMessage != nil)) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveProfile() async {
        isSaving = true
        
        do {
            _ = try await APIClient.shared.updateUser(nickname: nickname, avatarUrl: nil)
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
