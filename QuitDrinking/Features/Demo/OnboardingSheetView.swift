import SwiftUI
import SwiftData

/// 1 頁式個人化設定引導 Sheet（可從 MAIC Demo 控制台開啟供簡報開場錄影）。
struct OnboardingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let progress: PlayerProgress
    @Environment(\.modelContext) private var modelContext
    let records: [CheckInRecord]

    @State private var showSaveError = false

    @State private var draftMode: GoalMode
    @State private var draftWeeklyLimit: Int
    @State private var draftCostNTD: Int
    @State private var draftCalories: Int

    init(progress: PlayerProgress, records: [CheckInRecord]) {
        self.progress = progress
        self.records = records
        _draftMode = State(initialValue: progress.goalMode)
        _draftWeeklyLimit = State(initialValue: progress.weeklySessionLimit)
        _draftCostNTD = State(initialValue: progress.costPerDrinkNTD)
        _draftCalories = State(initialValue: progress.caloriesPerDrink)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("我的目標", selection: $draftMode) {
                        ForEach(GoalMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    if draftMode == .moderationBudget {
                        Stepper(value: $draftWeeklyLimit, in: 1...4) {
                            Text("每週最多喝 \(draftWeeklyLimit) 次").monospacedDigit()
                        }
                    }
                } footer: {
                    Text(draftMode == .strictAbstinence
                         ? "沒喝酒的日子可以攻擊怪獸。有喝酒時，記下發生了什麼，就能使用誠實護盾。"
                         : "每週一重新計算次數。額度內飲酒保留連勝；用完額度後，喝酒仍可用誠實護盾記錄。")
                }
                .listRowBackground(ThemeTokens.cardSurface)

                Section {
                    Stepper(value: $draftCostNTD, in: 50...2000, step: 50) {
                        Text("酒錢  NT$ \(draftCostNTD)").monospacedDigit()
                    }
                    Stepper(value: $draftCalories, in: 100...1500, step: 40) {
                        Text("熱量  \(draftCalories) kcal").monospacedDigit()
                    }
                } header: {
                    Text("平常喝一次酒")
                } footer: {
                    Text("每記下一個沒喝酒的日子，手帳就按這些金額和熱量估算一次。之後可以再調整。")
                }
                .listRowBackground(ThemeTokens.cardSurface)
            }
            .scrollContentBackground(.hidden)
            .background(ThemeTokens.canvasBackground)
            .navigationTitle("我的飲酒目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("儲存目標") {
                    progress.goalMode = draftMode
                    progress.weeklySessionLimit = draftWeeklyLimit
                    progress.costPerDrinkNTD = draftCostNTD
                    progress.caloriesPerDrink = draftCalories
                    do {
                        try CombatEngine.saveAndSync(progress: progress, records: records, context: modelContext)
                        dismiss()
                    } catch {
                        showSaveError = true
                    }
                }
                .buttonStyle(TactilePrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(ThemeTokens.canvasBackground.opacity(0.96))
            }
        }
        .preferredColorScheme(.dark)
        .alert("無法儲存目標", isPresented: $showSaveError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("你的選擇仍在這個畫面，請稍後再試一次。")
        }
    }
}
