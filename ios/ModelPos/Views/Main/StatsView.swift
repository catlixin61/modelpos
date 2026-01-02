// 统计视图

import SwiftUI
import Charts

/// 统计视图
struct StatsView: View {
    @State private var selectedPeriod: StatsPeriod = .week
    @State private var weeklyStats: WeeklyStats?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0d1117")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 周期选择器
                        Picker("统计周期", selection: $selectedPeriod) {
                            ForEach(StatsPeriod.allCases, id: \.self) { period in
                                Text(period.title).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .frame(height: 300)
                        } else if let stats = weeklyStats {
                            // 总览卡片
                            OverviewCard(stats: stats)
                            
                            // 图表
                            WeeklyChartCard(dailyStats: stats.dailyStats)
                            
                            // 每日详情
                            DailyDetailsList(dailyStats: stats.dailyStats)
                        } else if let error = errorMessage {
                            ErrorCard(message: error, onRetry: loadStats)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("姿态统计")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadStats()
            }
            .refreshable {
                await loadStats()
            }
        }
    }
    
    private func loadStats() async {
        isLoading = true
        errorMessage = nil
        
        do {
            weeklyStats = try await APIClient.shared.getWeeklyStats()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

/// 统计周期
enum StatsPeriod: CaseIterable {
    case week
    case month
    
    var title: String {
        switch self {
        case .week: return "本周"
        case .month: return "本月"
        }
    }
}

/// 总览卡片
struct OverviewCard: View {
    let stats: WeeklyStats
    
    var body: some View {
        VStack(spacing: 20) {
            // 正确率圆环
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 16)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: stats.averageCorrectRate)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "10b981")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(stats.averagePercentage)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("平均正确率")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.vertical, 10)
            
            // 统计数据
            HStack(spacing: 0) {
                OverviewStatItem(
                    title: "正确时长",
                    value: formatDuration(stats.totalCorrectDuration),
                    icon: "checkmark.circle.fill",
                    color: Color(hex: "10b981")
                )
                
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.1))
                
                OverviewStatItem(
                    title: "不良时长",
                    value: formatDuration(stats.totalIncorrectDuration),
                    icon: "xmark.circle.fill",
                    color: Color(hex: "ef4444")
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
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// 总览统计项
struct OverviewStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

/// 周图表卡片
struct WeeklyChartCard: View {
    let dailyStats: [PostureStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("每日趋势")
                .font(.headline)
                .foregroundStyle(.white)
            
            Chart {
                ForEach(Array(dailyStats.enumerated()), id: \.offset) { index, stat in
                    BarMark(
                        x: .value("日期", formatWeekday(stat.date)),
                        y: .value("正确率", stat.correctPercentage)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(6)
                }
            }
            .frame(height: 180)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let intValue = value.as(Int.self) {
                        AxisValueLabel {
                            Text("\(intValue)%")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let stringValue = value.as(String.self) {
                            Text(stringValue)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
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
        .padding(.horizontal)
    }
    
    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

/// 每日详情列表
struct DailyDetailsList: View {
    let dailyStats: [PostureStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("每日详情")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(Array(dailyStats.enumerated()), id: \.offset) { _, stat in
                    DailyDetailRow(stat: stat)
                }
            }
            .padding(.horizontal)
        }
    }
}

/// 每日详情行
struct DailyDetailRow: View {
    let stat: PostureStats
    
    var body: some View {
        HStack {
            // 日期
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(stat.date))
                    .font(.subheadline)
                    .foregroundStyle(.white)
                
                Text(stat.formattedTotalDuration)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "10b981")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * stat.correctRate, height: 8)
                }
            }
            .frame(width: 100, height: 8)
            
            // 正确率
            Text("\(stat.correctPercentage)%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(rateColor(stat.correctRate))
                .frame(width: 50, alignment: .trailing)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "161b22"))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 E"
        return formatter.string(from: date)
    }
    
    private func rateColor(_ rate: Double) -> Color {
        if rate >= 0.8 {
            return Color(hex: "10b981")
        } else if rate >= 0.6 {
            return Color(hex: "f59e0b")
        } else {
            return Color(hex: "ef4444")
        }
    }
}

/// 错误卡片
struct ErrorCard: View {
    let message: String
    let onRetry: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button {
                Task { await onRetry() }
            } label: {
                Text("重试")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "667eea"))
                    .clipShape(Capsule())
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "161b22"))
        )
        .padding(.horizontal)
    }
}

#Preview {
    StatsView()
        .preferredColorScheme(.dark)
}
