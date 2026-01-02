// 首页 - 姿态监控视图

import SwiftUI

/// 首页视图
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var monitorService = PostureMonitorService.shared
    @StateObject private var bluetoothService = BluetoothService.shared
    
    @State private var showDeviceSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(hex: "0d1117")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 设备状态卡片
                        DeviceStatusCard(
                            isConnected: bluetoothService.state == .connected,
                            deviceName: bluetoothService.connectedDevice?.name ?? "未连接设备",
                            onTap: { showDeviceSheet = true }
                        )
                        
                        // 当前姿态卡片
                        CurrentPostureCard(
                            posture: monitorService.currentPosture,
                            isMonitoring: monitorService.state == .monitoring
                        )
                        
                        // 今日统计
                        TodayStatsCard(
                            correctDuration: monitorService.formattedCorrectDuration,
                            correctRate: monitorService.correctRate,
                            sessionDuration: monitorService.formattedSessionDuration
                        )
                        
                        // 控制按钮
                        MonitorControlButton(
                            state: monitorService.state,
                            onStart: { monitorService.startMonitoring() },
                            onPause: { monitorService.pauseMonitoring() },
                            onResume: { monitorService.resumeMonitoring() },
                            onStop: { monitorService.stopMonitoring() }
                        )
                        .padding(.top, 16)
                    }
                    .padding()
                }
            }
            .navigationTitle("姿态监控")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDeviceSheet = true
                    } label: {
                        Image(systemName: bluetoothService.state == .connected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundStyle(bluetoothService.state == .connected ? Color(hex: "667eea") : .gray)
                    }
                }
            }
            .sheet(isPresented: $showDeviceSheet) {
                DeviceScanSheet()
            }
        }
    }
}

/// 设备状态卡片
struct DeviceStatusCard: View {
    let isConnected: Bool
    let deviceName: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(isConnected ? Color(hex: "667eea").opacity(0.15) : Color.gray.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: isConnected ? "checkmark.circle.fill" : "x.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isConnected ? Color(hex: "667eea") : .gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isConnected ? "设备已连接" : "设备未连接")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(deviceName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "161b22"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// 当前姿态卡片
struct CurrentPostureCard: View {
    let posture: PostureData?
    let isMonitoring: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Text("当前姿态")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if isMonitoring {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("监控中")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            // 姿态显示
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 160, height: 160)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: posture?.confidence != nil ? CGFloat(posture!.confidence) : 0)
                    .stroke(
                        postureColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: posture?.confidence)
                
                VStack(spacing: 8) {
                    Image(systemName: postureIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(postureColor)
                    
                    Text(postureName)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 20)
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
    }
    
    private var postureColor: Color {
        guard let posture = posture else { return .gray }
        return posture.isCorrect ? Color(hex: "10b981") : Color(hex: "ef4444")
    }
    
    private var postureIcon: String {
        guard let posture = posture else { return "figure.stand" }
        
        switch posture.postureType {
        case "correct": return "figure.stand"
        case "head_forward": return "figure.walk"
        case "slouch": return "figure.roll"
        case "lean_left", "lean_right": return "figure.wave"
        default: return "figure.stand"
        }
    }
    
    private var postureName: String {
        guard let posture = posture else { return "等待数据" }
        return AppConfig.postureTypes[posture.postureType]?.name ?? posture.postureType
    }
}

/// 今日统计卡片
struct TodayStatsCard: View {
    let correctDuration: String
    let correctRate: Double
    let sessionDuration: String
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("本次监控")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                // 正确时长
                StatItem(
                    title: "正确时长",
                    value: correctDuration,
                    color: Color(hex: "10b981")
                )
                
                // 正确率
                StatItem(
                    title: "正确率",
                    value: "\(Int(correctRate * 100))%",
                    color: Color(hex: "667eea")
                )
                
                // 总时长
                StatItem(
                    title: "总时长",
                    value: sessionDuration,
                    color: Color(hex: "f59e0b")
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "161b22"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

/// 统计项
struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

/// 监控控制按钮
struct MonitorControlButton: View {
    let state: MonitoringState
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            switch state {
            case .idle:
                // 开始按钮
                Button(action: onStart) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("开始监控")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
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
                
            case .monitoring:
                // 暂停按钮
                Button(action: onPause) {
                    HStack {
                        Image(systemName: "pause.fill")
                        Text("暂停")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "f59e0b"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // 停止按钮
                Button(action: onStop) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("结束")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "ef4444"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
            case .paused:
                // 继续按钮
                Button(action: onResume) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("继续")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
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
                
                // 停止按钮
                Button(action: onStop) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("结束")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "ef4444"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
