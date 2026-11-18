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
    @ScaledMetric(relativeTo: .largeTitle) private var metricSize = 43.0

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
                VStack(alignment: .leading, spacing: 28) {
                    savingsReceipt
                    weeklyLog
                    Divider().overlay(ThemeTokens.cardStroke)
                    drinkingContexts(stats: CombatEngine.triggerBreakdown(from: records))
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
            .background(ThemeTokens.canvasBackground)
            .navigationTitle("飲酒手帳")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBaselineEditor = true
                    } label: {
                        Label("調整估算", systemImage: "slider.horizontal.3")
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

    private var savingsReceipt: some View {
        let metrics = CombatEngine.impactSummary(for: progress)
        return VStack(alignment: .leading, spacing: 12) {
            Text("估計省下的酒錢")
                .font(ThemeTokens.printTitleFont(.title3))
                .accessibilityAddTraits(.isHeader)
            Text("NT$ \(metrics.totalSavedNTD.formatted())")
                .font(ThemeTokens.roundedNumericFont(size: metricSize, weight: .bold))
                .foregroundStyle(ThemeTokens.printGreen)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(2)
            Divider().overlay(ThemeTokens.receiptInk.opacity(0.55))
            receiptLine("沒喝酒的日子", value: "\(progress.totalCleanCheckIns.formatted()) 天")
            receiptLine("每次酒錢", value: "NT$ \(progress.costPerDrinkNTD.formatted())")
            Divider().overlay(ThemeTokens.receiptInk.opacity(0.35))
            receiptLine("估計少攝取的熱量", value: "\(metrics.totalCaloriesAvoided.formatted()) kcal")
            Text("約 \(metrics.riceBowlsEquivalent.formatted(.number.precision(.fractionLength(1)))) 碗白飯")
                .font(.footnote)
                .monospacedDigit()
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(ThemeTokens.receiptInk)
        .background(ThemeTokens.receiptPaper, in: ReceiptOutline())
    }

    private func receiptLine(_ title: LocalizedStringKey, value: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(title)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(value).bold().monospacedDigit()
        }
        .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .regular))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Swift Charts 7-Day Trend

    private var weeklyLog: some View {
        let buckets = CombatEngine.recentSevenDayBuckets(progress: progress, records: records, now: referenceDate, calendar: chartCalendar)
        let soberDays = buckets.count { $0.outcome == .soberAttack }
        let drinkingDays = buckets.count { $0.outcome == .withinBudgetDrink || $0.outcome == .honestShieldRelapse }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("近七天的打卡")
                        .font(ThemeTokens.printTitleFont(.title2))
                        .accessibilityAddTraits(.isHeader)
                        .foregroundStyle(ThemeTokens.inkPrimary)
                    if soberDays + drinkingDays > 0 {
                        Text("\(soberDays) 天沒喝酒，\(drinkingDays) 天有喝酒")
                            .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .medium))
                            .monospacedDigit()
                    }
                    Text(soberDays + drinkingDays > 0 ? "圖中是每天最後一次打卡的攻擊或回血量（HP）。" : "到戰場記下今天有沒有喝酒，就會留下第一筆紀錄。")
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
                .accessibilityValue(bucket.outcome.map { "\(ledgerLabel(for: $0))，\(bucket.magnitude) HP" } ?? "未打卡")
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

    private func ledgerLabel(for outcome: CheckInOutcomeType) -> String {
        switch outcome {
        case .soberAttack: "沒喝酒"
        case .withinBudgetDrink: "額度內飲酒"
        case .honestShieldRelapse: "飲酒・護盾"
        }
    }

    private func legendItem(for outcome: CheckInOutcomeType) -> some View {
        Label {
            Text(ledgerLabel(for: outcome))
                .foregroundStyle(ThemeTokens.inkSecondary)
        } icon: {
            Image(systemName: symbol(for: outcome))
                .foregroundStyle(color(for: outcome))
        }
        .font(.caption)
    }

    // MARK: - Trigger Breakdown

    private func drinkingContexts(stats: [TriggerStatItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("喝酒時的情境")
                    .font(ThemeTokens.printTitleFont(.title2))
                    .accessibilityAddTraits(.isHeader)
                    .foregroundStyle(ThemeTokens.inkPrimary)
                Spacer()
                Text("\(progress.insightXP) XP")
                    .accessibilityLabel("誠實紀錄經驗值 \(progress.insightXP)")
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
                    Text("還沒有情境紀錄。下次開啟誠實護盾時，可以勾選當時發生了什麼。")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("依誠實護盾紀錄中各情境被勾選的比例排列。")
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
    }
}

/// A single perforated edge marks the subtotal slip inside the ledger.
private struct ReceiptOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let teeth = max(1, Int(rect.width / 10))
        let width = rect.width / CGFloat(teeth)
        var path = Path()
        path.move(to: .init(x: rect.minX, y: rect.minY))
        path.addLine(to: .init(x: rect.maxX, y: rect.minY))
        path.addLine(to: .init(x: rect.maxX, y: rect.maxY - 3))
        for step in 0..<teeth {
            let right = rect.maxX - CGFloat(step) * width
            path.addLine(to: .init(x: right - width / 2, y: rect.maxY))
            path.addLine(to: .init(x: right - width, y: rect.maxY - 3))
        }
        path.closeSubpath()
        return path
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
                Section("平常喝一次酒") {
                    Stepper(value: $cost, in: 50...2000, step: 50) {
                        HStack {
                            Text("酒錢")
                            Spacer()
                            Text("NT$ \(cost)")
                                .monospacedDigit()
                                .foregroundStyle(ThemeTokens.mintVitality)
                        }
                    }

                    Stepper(value: $calories, in: 100...1500, step: 40) {
                        HStack {
                            Text("酒的熱量")
                            Spacer()
                            Text("\(calories) kcal")
                                .monospacedDigit()
                                .foregroundStyle(ThemeTokens.amberShield)
                        }
                    }
                }
                .listRowBackground(ThemeTokens.cardSurface)
            }
            .scrollContentBackground(.hidden)
            .background(ThemeTokens.canvasBackground)
            .navigationTitle("調整酒錢與熱量估算")
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
