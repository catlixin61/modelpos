// 北岛 AI 姿态矫正器 - iOS 客户端
// 主入口文件

import SwiftUI
import SwiftData

@main
struct ModelPosApp: App {
    // 应用状态管理
    @StateObject private var appState = AppState()
    
    // SwiftData 容器
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedPostureLog.self,
            CachedDevice.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
