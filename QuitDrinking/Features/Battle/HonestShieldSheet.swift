import SwiftUI

/// 「今天有喝・誠實紀錄」彈窗表單，依據是否超出每週安全額度動態切換「理性小酌」與「誠實護盾」視覺預覽。
struct HonestShieldSheet: View {
    let monsterSpec: MonsterSpec
    let willTriggerShield: Bool
    let weeklyUsed: Int
    let weeklyLimit: Int
    let isModerationMode: Bool
    let onSubmit: (_ units: Int, _ triggers: [RelapseTriggerTag], _ note: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var units: Int = 1
    @State private var selectedTriggers: Set<RelapseTriggerTag> = [.socialGathering]
    @State private var note: String = ""

    private var predictedHeal: Int {
        if willTriggerShield {
            return CombatEngine.honestShieldHealAmount(units: units, monsterMaxHP: monsterSpec.maxHP)
        } else {
            return CombatEngine.withinBudgetHealAmount(units: units, monsterMaxHP: monsterSpec.maxHP)
        }
    }

    private var canSubmit: Bool {
        !willTriggerShield || !selectedTriggers.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusBanner

                    unitsSection

                    triggersSection

                    noteSection
                }
                .padding(20)
            }
            .background(ThemeTokens.canvasBackground)
            .navigationTitle(willTriggerShield ? "開啟誠實護盾" : "額度內小酌紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        onSubmit(units, Array(selectedTriggers), note.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    } label: {
                        Label(
                            willTriggerShield ? "確認紀錄・啟動誠實護盾 (+\(predictedHeal) HP)" : "確認紀錄・保留連勝 (+\(predictedHeal) HP)",
                            systemImage: willTriggerShield ? "shield.lefthalf.filled" : "checkmark.seal.fill"
                        )
                    }
                    .buttonStyle(
                        TactilePrimaryButtonStyle(
                            fillColor: willTriggerShield ? ThemeTokens.amberShield : ThemeTokens.skyModeration,
                            foregroundColor: ThemeTokens.canvasBackground
                        )
                    )
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.45)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(ThemeTokens.canvasBackground.opacity(0.96))
            }
        }
        .preferredColorScheme(.dark)
    }

    private var statusBanner: some View {
        let bannerColor = willTriggerShield ? ThemeTokens.amberShield : ThemeTokens.skyModeration
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: willTriggerShield ? "shield.lefthalf.filled" : "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(bannerColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(willTriggerShield ? "誠實紀錄＝護盾展開・絕不歸零" : "仍在安全額度內（本週已用 \(weeklyUsed)/\(weeklyLimit) 次）")
                    .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                    .foregroundStyle(ThemeTokens.inkPrimary)

                Text(
                    willTriggerShield
                    ? "\(monsterSpec.name)只會微幅回復 \(predictedHeal) HP（單次上限 20%），關卡與累計省錢全部保留，並獲得 +25 反省經驗。"
                    : "這場小酌在你的減量計畫內，每日攻擊連勝將繼續保留，怪獸僅輕微回復 \(predictedHeal) HP。"
                )
                .font(.subheadline)
                .foregroundStyle(ThemeTokens.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                .fill(bannerColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                        .strokeBorder(bannerColor.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("這次喝了幾標準杯？")
                .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .semibold))
                .foregroundStyle(ThemeTokens.inkPrimary)

            HStack {
                Button {
                    if units > 1 { units -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(units > 1 ? ThemeTokens.inkPrimary : ThemeTokens.inkSecondary.opacity(0.4))
                }
                .accessibilityLabel("減少一杯")
                .disabled(units <= 1)

                Spacer()

                VStack(spacing: 2) {
                    Text("\(units) \(units == 6 ? "+" : "")杯")
                        .font(ThemeTokens.roundedNumericFont(size: 28, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(ThemeTokens.inkPrimary)
                    Text("約 1 罐啤酒 / 1 杯紅酒")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }

                Spacer()

                Button {
                    if units < 6 { units += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(units < 6 ? ThemeTokens.inkPrimary : ThemeTokens.inkSecondary.opacity(0.4))
                }
                .accessibilityLabel("增加一杯")
                .disabled(units >= 6)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: ThemeTokens.pillRadius, style: .continuous)
                    .fill(ThemeTokens.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeTokens.pillRadius, style: .continuous)
                            .strokeBorder(ThemeTokens.cardStroke, lineWidth: 1)
                    )
            )
        }
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(willTriggerShield ? "是什麼情境想喝？（至少選 1 項）" : "情境標籤（選填）")
                    .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .semibold))
                    .foregroundStyle(ThemeTokens.inkPrimary)
                Spacer()
                if isModerationMode && !willTriggerShield {
                    Text("額度內不計入破戒")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.skyModeration)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RelapseTriggerTag.allCases) { tag in
                    let isSelected = selectedTriggers.contains(tag)
                    Button {
                        if isSelected {
                            if selectedTriggers.count > 1 || !willTriggerShield {
                                selectedTriggers.remove(tag)
                            }
                        } else {
                            selectedTriggers.insert(tag)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : tag.symbolName)
                                .font(.subheadline)
                            Text(tag.rawValue)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(isSelected ? ThemeTokens.amberShield : ThemeTokens.inkPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? ThemeTokens.amberShield.opacity(0.14) : ThemeTokens.cardSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(isSelected ? ThemeTokens.amberShield : ThemeTokens.cardStroke, lineWidth: 1.2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("給自己的備忘（選填）")
                .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .semibold))
                .foregroundStyle(ThemeTokens.inkPrimary)

            TextField("例如：聚會前先點氣泡水⋯⋯", text: $note)
                .font(.subheadline)
                .foregroundStyle(ThemeTokens.inkPrimary)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ThemeTokens.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(ThemeTokens.cardStroke, lineWidth: 1)
                        )
                )
        }
    }
}
