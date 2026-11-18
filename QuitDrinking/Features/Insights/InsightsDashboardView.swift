import SwiftUI
import SwiftData
import Charts

/// 戰績換算（省錢／白飯熱量）、近 7 日戰鬥趨勢 Swift Charts 與誘因洞察。
struct InsightsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .title2) private var metricSize = 22.0

    let progress: PlayerProgress
    let records: [CheckInRecord]

    @State private var showBaselineEditor = false
    @State private var referenceDate = Date.now

    private var chartCalendar: Calendar {
        var result = calendar
        result.timeZone = timeZone
        return result
    }

    private func refreshDate() {
        let now = Date.now
        if !chartCalendar.isDate(referenceDate, inSameDayAs: now) {
            referenceDate = now
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroMetricsGrid
                    sevenDayChartCard
                    triggerInsightsCard(stats: CombatEngine.triggerBreakdown(from: records))
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
            .onAppear(perform: refreshDate)
            .onChange(of: scenePhase) {
                if scenePhase == .active { refreshDate() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshDate()
            }
            .sheet(isPresented: $showBaselineEditor) {
                BaselineMetricEditorSheet(progress: progress) { cost, calories in
                    progress.costPerDrinkNTD = cost
                    progress.caloriesPerDrink = calories
                    try CombatEngine.saveAndSync(progress: progress, records: records, context: modelContext)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Hero Metrics

    private var heroMetricsGrid: some View {
        let metrics = CombatEngine.impactSummary(for: progress)
        let layout = dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
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
                footnote: "約 \(metrics.riceBowlsEquivalent.formatted(.number.precision(.fractionLength(1)))) 碗白飯",
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
                .font(ThemeTokens.roundedNumericFont(size: metricSize, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(ThemeTokens.inkPrimary)
                .minimumScaleFactor(0.75)
                .lineLimit(2)

            Text(footnote)
                .font(.caption2)
                .foregroundStyle(ThemeTokens.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
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
        let buckets = CombatEngine.recentSevenDayBuckets(progress: progress, records: records, now: referenceDate, calendar: chartCalendar)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("近 7 日戰鬥趨勢")
                        .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                        .foregroundStyle(ThemeTokens.inkPrimary)
                    Text(buckets.contains { $0.outcome != nil } ? "每日顯示最後一筆攻擊或回血量（HP）" : "這 7 天還沒有戰役紀錄")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }
                Spacer()
            }

            Chart(buckets) { bucket in
                BarMark(
                    x: .value("日期", bucket.dayLabel),
                    y: .value("戰鬥量（HP）", bucket.magnitude)
                )
                .foregroundStyle(color(for: bucket.outcome))
                .cornerRadius(6)
                .annotation(position: .top, spacing: 2) {
                    if let outcome = bucket.outcome {
                        Image(systemName: symbol(for: outcome))
                            .font(.caption2)
                            .foregroundStyle(color(for: outcome))
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(bucket.dayLabel)
                .accessibilityValue(bucket.outcome.map { "\($0.displayTitle)，\(bucket.magnitude) HP" } ?? "未打卡")
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

            let legendLayout = dynamicTypeSize >= .xxLarge
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(spacing: 12))
            legendLayout {
                legendItem(for: .soberAttack)
                legendItem(for: .withinBudgetDrink)
                legendItem(for: .honestShieldRelapse)
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

    private func symbol(for outcome: CheckInOutcomeType) -> String {
        switch outcome {
        case .soberAttack: "bolt.fill"
        case .withinBudgetDrink: "drop.fill"
        case .honestShieldRelapse: "shield.fill"
        }
    }

    private func legendItem(for outcome: CheckInOutcomeType) -> some View {
        Label {
            Text(outcome.displayTitle)
                .foregroundStyle(ThemeTokens.inkSecondary)
        } icon: {
            Image(systemName: symbol(for: outcome))
                .foregroundStyle(color(for: outcome))
        }
        .font(.caption)
    }

    // MARK: - Trigger Breakdown

    private func triggerInsightsCard(stats: [TriggerStatItem]) -> some View {
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

            if stats.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(ThemeTokens.mintVitality)
                        .accessibilityHidden(true)
                    Text("使用誠實護盾記下喝酒的原因後，就能在這裡看見最常遇到的情境。")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("依各誘因占全部勾選次數的比例排列")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                    ForEach(stats) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(item.tag.rawValue, systemImage: item.tag.symbolName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(ThemeTokens.inkPrimary)
                                Spacer()
                                Text("\(item.ratio, format: .percent.precision(.fractionLength(0)))（\(item.count) 次）")
                                    .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(ThemeTokens.amberShield)
                            }

                            ProgressView(value: item.ratio)
                                .tint(ThemeTokens.amberShield)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
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
    @State private var cost: Int
    @State private var calories: Int
    @State private var showSaveError = false
    let onSave: (Int, Int) throws -> Void

    init(progress: PlayerProgress, onSave: @escaping (Int, Int) throws -> Void) {
        _cost = State(initialValue: progress.costPerDrinkNTD)
        _calories = State(initialValue: progress.caloriesPerDrink)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("個人單次飲酒基準換算") {
                    Stepper(value: $cost, in: 50...2000, step: 50) {
                        HStack {
                            Text("平均每次花費")
                            Spacer()
                            Text("NT$ \(cost)")
                                .monospacedDigit()
                                .foregroundStyle(ThemeTokens.mintVitality)
                        }
                    }

                    Stepper(value: $calories, in: 100...1500, step: 40) {
                        HStack {
                            Text("平均每次熱量")
                            Spacer()
                            Text("\(calories) kcal")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        do {
                            try onSave(cost, calories)
                            dismiss()
                        } catch {
                            showSaveError = true
                        }
                    }
                    .foregroundStyle(ThemeTokens.mintVitality)
                }
            }
        }
        .alert("換算基準未能儲存", isPresented: $showSaveError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("調整的數值已保留在這裡，可再按「完成」重試。")
        }
        .preferredColorScheme(.dark)
    }
}
