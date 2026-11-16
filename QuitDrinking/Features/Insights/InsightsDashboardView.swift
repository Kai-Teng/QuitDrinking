import SwiftUI
import SwiftData
import Charts
import WidgetKit

/// 分頁二：戰績換算（省錢／白飯熱量）、近 7 日戰鬥趨勢 Swift Charts 與誘因洞察。
struct InsightsDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    let progress: PlayerProgress
    let records: [CheckInRecord]

    @State private var showBaselineEditor = false

    private var metrics: ImpactMetrics {
        CombatEngine.impactSummary(for: progress)
    }

    private var chartBuckets: [DailyChartBucket] {
        CombatEngine.recentSevenDayBuckets(progress: progress, records: records)
    }

    private var triggerStats: [TriggerStatItem] {
        CombatEngine.triggerBreakdown(from: records)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroMetricsGrid
                    sevenDayChartCard
                    triggerInsightsCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .background(ThemeTokens.canvasBackground)
            .navigationTitle("戰績洞察")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBaselineEditor = true
                    } label: {
                        Label("酒單基準", systemImage: "slider.horizontal.3")
                            .font(.subheadline)
                    }
                    .foregroundStyle(ThemeTokens.mintVitality)
                }
            }
            .sheet(isPresented: $showBaselineEditor) {
                BaselineMetricEditorSheet(progress: progress) {
                    try? modelContext.save()
                    CombatEngine.syncSnapshot(progress: progress, records: records)
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Hero Metrics

    private var heroMetricsGrid: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "累積省下酒錢",
                value: "NT$ \(metrics.totalSavedNTD.formatted())",
                footnote: "已累計 \(progress.totalCleanCheckIns) 天清醒重擊",
                icon: "banknote.fill",
                accent: ThemeTokens.mintVitality
            )

            metricCard(
                title: "少攝取熱量",
                value: "\(metrics.totalCaloriesAvoided.formatted()) kcal",
                footnote: String(format: "約少吃 %.1f 碗白飯", metrics.riceBowlsEquivalent),
                icon: "flame.fill",
                accent: ThemeTokens.amberShield
            )
        }
    }

    private func metricCard(title: String, value: String, footnote: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ThemeTokens.inkSecondary)
            }

            Text(value)
                .font(ThemeTokens.roundedNumericFont(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(ThemeTokens.inkPrimary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(footnote)
                .font(.caption2)
                .foregroundStyle(ThemeTokens.inkSecondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                .fill(ThemeTokens.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                        .strokeBorder(ThemeTokens.cardStroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Swift Charts 7-Day Trend

    private var sevenDayChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("近 7 日戰鬥趨勢")
                        .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                        .foregroundStyle(ThemeTokens.inkPrimary)
                    Text("以當前模擬日向前推算 7 天戰役記錄")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }
                Spacer()
            }

            Chart(chartBuckets) { bucket in
                BarMark(
                    x: .value("日期", bucket.dayLabel),
                    y: .value("強度", bucket.magnitude)
                )
                .foregroundStyle(color(for: bucket.outcome))
                .cornerRadius(6)
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        .foregroundStyle(ThemeTokens.inkSecondary.opacity(0.25))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }
            }

            HStack(spacing: 14) {
                legendItem(color: ThemeTokens.mintVitality, label: "清醒攻擊")
                legendItem(color: ThemeTokens.skyModeration, label: "額度內小酌")
                legendItem(color: ThemeTokens.amberShield, label: "誠實護盾")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                .fill(ThemeTokens.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                        .strokeBorder(ThemeTokens.cardStroke, lineWidth: 1)
                )
        )
    }

    private func color(for outcome: CheckInOutcomeType?) -> Color {
        switch outcome {
        case .soberAttack: ThemeTokens.mintVitality
        case .withinBudgetDrink: ThemeTokens.skyModeration
        case .honestShieldRelapse: ThemeTokens.amberShield
        case .none: ThemeTokens.inkSecondary.opacity(0.15)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(ThemeTokens.inkSecondary)
        }
    }

    // MARK: - Trigger Breakdown

    private var triggerInsightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("誠實護盾・高風險誘因分析")
                    .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                    .foregroundStyle(ThemeTokens.inkPrimary)
                Spacer()
                Text("反省 \(progress.insightXP) XP")
                    .font(ThemeTokens.roundedTitleFont(.caption, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ThemeTokens.amberShield)
            }

            if triggerStats.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(ThemeTokens.mintVitality)
                    Text("目前還沒有超標或破戒觸發紀錄。當你開啟誠實護盾時，這裡會為你整理最常想喝酒的情境。")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(triggerStats) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(item.tag.rawValue, systemImage: item.tag.symbolName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(ThemeTokens.inkPrimary)
                                Spacer()
                                Text("\(Int(item.ratio * 100))%（\(item.count) 次）")
                                    .font(ThemeTokens.roundedNumericFont(size: 13, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(ThemeTokens.amberShield)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(ThemeTokens.canvasBackground.opacity(0.75))
                                    Capsule()
                                        .fill(ThemeTokens.amberShield)
                                        .frame(width: max(10, geo.size.width * item.ratio))
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                .fill(ThemeTokens.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                        .strokeBorder(ThemeTokens.cardStroke, lineWidth: 1)
                )
        )
    }
}

private struct BaselineMetricEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var progress: PlayerProgress
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("個人單次飲酒基準換算") {
                    Stepper(value: $progress.costPerDrinkNTD, in: 50...2000, step: 50) {
                        HStack {
                            Text("平均每次花費")
                            Spacer()
                            Text("NT$ \(progress.costPerDrinkNTD)")
                                .monospacedDigit()
                                .foregroundStyle(ThemeTokens.mintVitality)
                        }
                    }

                    Stepper(value: $progress.caloriesPerDrink, in: 100...1500, step: 40) {
                        HStack {
                            Text("平均每次熱量")
                            Spacer()
                            Text("\(progress.caloriesPerDrink) kcal")
                                .monospacedDigit()
                                .foregroundStyle(ThemeTokens.amberShield)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemeTokens.canvasBackground)
            .navigationTitle("調整換算基準")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onSave()
                        dismiss()
                    }
                    .foregroundStyle(ThemeTokens.mintVitality)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
