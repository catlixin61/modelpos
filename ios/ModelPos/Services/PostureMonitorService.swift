// 姿态监控服务 - 管理姿态检测和日志记录

import Foundation
import Combine
import SwiftData

/// 监控状态
enum MonitoringState {
    case idle       // 空闲
    case monitoring // 监控中
    case paused     // 已暂停
}

/// 姿态监控服务
@MainActor
final class PostureMonitorService: ObservableObject {
    static let shared = PostureMonitorService()
    
    // MARK: - Published 属性
    
    @Published private(set) var state: MonitoringState = .idle
    @Published private(set) var currentPosture: PostureData?
    @Published private(set) var sessionDuration: TimeInterval = 0
    @Published private(set) var correctDuration: TimeInterval = 0
    @Published private(set) var incorrectDuration: TimeInterval = 0
    @Published private(set) var postureHistory: [PostureData] = []
    
    // MARK: - 私有属性
    
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var lastPostureChange: Date?
    private var lastPostureType: String?
    
    private var modelContext: ModelContext?
    private var deviceId: Int?
    
    // MARK: - 计算属性
    
    var correctRate: Double {
        let total = correctDuration + incorrectDuration
        return total > 0 ? correctDuration / total : 0
    }
    
    var formattedSessionDuration: String {
        formatDuration(Int(sessionDuration))
    }
    
    var formattedCorrectDuration: String {
        formatDuration(Int(correctDuration))
    }
    
    // MARK: - 初始化
    
    private init() {
        setupPostureSubscription()
    }
    
    /// 配置 SwiftData 上下文
    func configure(modelContext: ModelContext, deviceId: Int) {
        self.modelContext = modelContext
        self.deviceId = deviceId
    }
    
    // MARK: - 监控控制
    
    /// 开始监控
    func startMonitoring() {
        guard state != .monitoring else { return }
        
        state = .monitoring
        sessionDuration = 0
        correctDuration = 0
        incorrectDuration = 0
        postureHistory = []
        lastPostureChange = Date()
        lastPostureType = nil
        
        // 启动计时器
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
    }
    
    /// 暂停监控
    func pauseMonitoring() {
        guard state == .monitoring else { return }
        
        state = .paused
        sessionTimer?.invalidate()
        
        // 保存当前姿态的持续时间
        savePendingPosture()
    }
    
    /// 恢复监控
    func resumeMonitoring() {
        guard state == .paused else { return }
        
        state = .monitoring
        lastPostureChange = Date()
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
    }
    
    /// 停止监控
    func stopMonitoring() {
        state = .idle
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // 保存最后的姿态
        savePendingPosture()
        
        // 同步未上传的日志
        Task {
            await syncPendingLogs()
        }
    }
    
    // MARK: - 私有方法
    
    private func setupPostureSubscription() {
        BluetoothService.shared.postureDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] postureData in
                self?.handlePostureData(postureData)
            }
            .store(in: &cancellables)
    }
    
    private func handlePostureData(_ postureData: PostureData) {
        guard state == .monitoring else { return }
        
        currentPosture = postureData
        postureHistory.append(postureData)
        
        // 限制历史记录数量
        if postureHistory.count > 100 {
            postureHistory.removeFirst()
        }
        
        // 检测姿态变化
        if lastPostureType != postureData.postureType {
            // 保存上一个姿态的持续时间
            savePendingPosture()
            
            lastPostureChange = postureData.timestamp
            lastPostureType = postureData.postureType
        }
    }
    
    private func updateDuration() {
        guard state == .monitoring else { return }
        
        sessionDuration += 1
        
        if let currentPosture = currentPosture {
            if currentPosture.isCorrect {
                correctDuration += 1
            } else {
                incorrectDuration += 1
            }
        }
    }
    
    private func savePendingPosture() {
        guard let lastType = lastPostureType,
              let lastChange = lastPostureChange,
              let deviceId = deviceId,
              let modelContext = modelContext else { return }
        
        let duration = Int(Date().timeIntervalSince(lastChange))
        
        guard duration > 0 else { return }
        
        let isCorrect = AppConfig.postureTypes[lastType]?.isCorrect ?? false
        
        let log = CachedPostureLog(
            deviceId: deviceId,
            postureType: lastType,
            duration: duration,
            isCorrect: isCorrect,
            recordedAt: lastChange
        )
        
        modelContext.insert(log)
        
        do {
            try modelContext.save()
        } catch {
            print("保存姿态日志失败: \(error)")
        }
    }
    
    /// 同步待上传的日志
    func syncPendingLogs() async {
        guard let modelContext = modelContext else { return }
        
        // 查询未同步的日志
        let descriptor = FetchDescriptor<CachedPostureLog>(
            predicate: #Predicate { !$0.isSynced }
        )
        
        do {
            let pendingLogs = try modelContext.fetch(descriptor)
            
            guard !pendingLogs.isEmpty else { return }
            
            // 转换为 API 请求格式
            let createRequests = pendingLogs.map { $0.toCreateRequest() }
            
            // 上传到服务器
            try await APIClient.shared.uploadPostureLogs(createRequests)
            
            // 标记为已同步
            for log in pendingLogs {
                log.isSynced = true
            }
            
            try modelContext.save()
            
        } catch {
            print("同步日志失败: \(error)")
        }
    }
    
    // MARK: - 工具方法
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
