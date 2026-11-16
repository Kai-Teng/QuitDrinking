import SwiftUI

/// 1 頁式個人化設定引導 Sheet（可從 MAIC Demo 控制台開啟供簡報開場錄影）。
struct OnboardingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let progress: PlayerProgress
    let onConfirm: () -> Void

    @State private var draftMode: GoalMode
    @State private var draftWeeklyLimit: Int
    @State private var draftCostNTD: Int
    @State private var draftCalories: Int

    init(progress: PlayerProgress, onConfirm: @escaping () -> Void) {
        self.progress = progress
        self.onConfirm = onConfirm
        _draftMode = State(initialValue: progress.goalMode)
        _draftWeeklyLimit = State(initialValue: progress.weeklySessionLimit)
        _draftCostNTD = State(initialValue: progress.costPerDrinkNTD)
        _draftCalories = State(initialValue: progress.caloriesPerDrink)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("設定你的破曉戰役")
                            .font(ThemeTokens.roundedNumericFont(size: 28, weight: .bold))
                            .foregroundStyle(ThemeTokens.inkPrimary)
                        Text("不用把失敗看成歸零，每一步清醒都在削弱眼前的飲酒心魔。")
                            .font(.subheadline)
                            .foregroundStyle(ThemeTokens.inkSecondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. 選擇戰役模式")
                            .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                            .foregroundStyle(ThemeTokens.inkPrimary)

                        ForEach(GoalMode.allCases) { mode in
                            let selected = draftMode == mode
                            Button {
                                draftMode = mode
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selected ? ThemeTokens.mintVitality : ThemeTokens.inkSecondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mode.displayName)
                                            .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                                            .foregroundStyle(ThemeTokens.inkPrimary)
                                        Text(mode.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(ThemeTokens.inkSecondary)
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                                        .fill(selected ? ThemeTokens.mintVitality.opacity(0.12) : ThemeTokens.cardSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                                                .strokeBorder(selected ? ThemeTokens.mintVitality : ThemeTokens.cardStroke, lineWidth: 1.4)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if draftMode == .moderationBudget {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("2. 每週安全飲酒次數上限")
                                .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                                .foregroundStyle(ThemeTokens.inkPrimary)

                            Stepper(value: $draftWeeklyLimit, in: 1...4) {
                                Text("每週最多 \(draftWeeklyLimit) 次（額度內不破連勝）")
                                    .font(.subheadline.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(ThemeTokens.skyModeration)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: ThemeTokens.pillRadius, style: .continuous)
                                    .fill(ThemeTokens.cardSurface)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(draftMode == .moderationBudget ? "3. 單次飲酒換算基準" : "2. 單次飲酒換算基準")
                            .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                            .foregroundStyle(ThemeTokens.inkPrimary)

                        VStack(spacing: 12) {
                            Stepper(value: $draftCostNTD, in: 50...2000, step: 50) {
                                HStack {
                                    Text("平均酒錢")
                                    Spacer()
                                    Text("NT$ \(draftCostNTD)")
                                        .monospacedDigit()
                                        .foregroundStyle(ThemeTokens.mintVitality)
                                }
                            }
                            Divider().overlay(ThemeTokens.cardStroke)
                            Stepper(value: $draftCalories, in: 100...1500, step: 40) {
                                HStack {
                                    Text("平均熱量")
                                    Spacer()
                                    Text("\(draftCalories) kcal")
                                        .monospacedDigit()
                                        .foregroundStyle(ThemeTokens.amberShield)
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(ThemeTokens.inkPrimary)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: ThemeTokens.pillRadius, style: .continuous)
                                .fill(ThemeTokens.cardSurface)
                        )
                    }
                }
                .padding(20)
            }
            .background(ThemeTokens.canvasBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("開始破曉之旅") {
                    progress.goalMode = draftMode
                    progress.weeklySessionLimit = draftWeeklyLimit
                    progress.costPerDrinkNTD = draftCostNTD
                    progress.caloriesPerDrink = draftCalories
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(TactilePrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(ThemeTokens.canvasBackground.opacity(0.96))
            }
        }
        .preferredColorScheme(.dark)
    }
}
