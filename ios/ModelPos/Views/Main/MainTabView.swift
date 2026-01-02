// 主标签页视图

import SwiftUI

/// 主标签页视图
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 首页 - 监控
            HomeView()
                .tabItem {
                    Label("监控", systemImage: "waveform.path.ecg")
                }
                .tag(0)
            
            // 统计
            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }
                .tag(1)
            
            // 设备
            DevicesView()
                .tabItem {
                    Label("设备", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(2)
            
            // 我的
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(Color(hex: "667eea"))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
