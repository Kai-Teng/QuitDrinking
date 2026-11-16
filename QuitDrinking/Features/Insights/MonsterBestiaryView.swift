import SwiftUI

/// 分頁三：Lv.1～Lv.4 怪獸圖鑑、稱號里程碑與通關後再戰入口。
struct MonsterBestiaryView: View {
    let progress: PlayerProgress
    let onRematch: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerBanner

                    ForEach(MonsterCatalog.all) { spec in
                        monsterCard(spec)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .background(ThemeTokens.canvasBackground)
            .navigationTitle("怪獸圖鑑")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var headerBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: progress.hasCompletedCampaign ? "crown.fill" : "shield.lefthalf.filled")
                .font(.title2.weight(.bold))
                .foregroundStyle(progress.hasCompletedCampaign ? ThemeTokens.amberShield : ThemeTokens.mintVitality)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill((progress.hasCompletedCampaign ? ThemeTokens.amberShield : ThemeTokens.mintVitality).opacity(0.16))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(progress.hasCompletedCampaign ? "已解鎖「破曉勇者」・圖鑑再戰開放" : "已擊敗 \(progress.defeatedMonsterLevels.count) / \(MonsterCatalog.all.count) 隻心魔")
                    .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                    .foregroundStyle(ThemeTokens.inkPrimary)
                Text(progress.hasCompletedCampaign ? "點選下方任一關卡可隨時發起再次挑戰，累計戰績全面保留。" : "通關 Lv.4 心魔魔王後，可於圖鑑重溫任意戰役。")
                    .font(.caption)
                    .foregroundStyle(ThemeTokens.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                .fill(ThemeTokens.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                        .strokeBorder(ThemeTokens.cardStroke, lineWidth: 1)
                )
        )
    }

    private func monsterCard(_ spec: MonsterSpec) -> some View {
        let isDefeated = progress.defeatedMonsterLevels.contains(spec.level)
        let isCurrent = !CombatEngine.isCampaignVictoryStandby(progress) && progress.activeMonsterLevel == spec.level
        let isUnlocked = isDefeated || isCurrent || progress.hasCompletedCampaign
        let accent = Color(hex: spec.accentHex)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUnlocked ? accent.opacity(0.16) : ThemeTokens.canvasBackground.opacity(0.6))
                        .frame(width: 58, height: 58)
                    Image(systemName: isUnlocked ? spec.symbolName : "lock.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(isUnlocked ? accent : ThemeTokens.inkSecondary.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Lv.\(spec.level)")
                            .font(ThemeTokens.roundedTitleFont(.caption2, weight: .bold))
                            .foregroundStyle(isUnlocked ? ThemeTokens.canvasBackground : ThemeTokens.inkSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(isUnlocked ? accent : ThemeTokens.cardElevated))

                        Text(isUnlocked ? spec.name : "未解鎖強敵")
                            .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                            .foregroundStyle(ThemeTokens.inkPrimary)
                    }

                    Text(isUnlocked ? spec.subtitle : "擊敗 Lv.\(spec.level - 1) 怪獸後現身")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }

                Spacer(minLength: 0)
            }

            HStack {
                Label("稱號：\(spec.titleReward)", systemImage: "medal.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isDefeated ? ThemeTokens.amberShield : ThemeTokens.inkSecondary)

                Spacer()

                if isCurrent {
                    Text("交戰中 \(progress.currentMonsterHP)/\(spec.maxHP) HP")
                        .font(ThemeTokens.roundedNumericFont(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(ThemeTokens.mintVitality)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(ThemeTokens.mintVitality.opacity(0.14)))
                } else if progress.hasCompletedCampaign {
                    Button {
                        onRematch(spec.level)
                    } label: {
                        Text("再次挑戰")
                            .font(ThemeTokens.roundedTitleFont(.caption, weight: .bold))
                            .foregroundStyle(ThemeTokens.canvasBackground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(accent))
                    }
                } else if isDefeated {
                    Label("已擊敗", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ThemeTokens.mintVitality)
                } else {
                    Text("HP \(spec.maxHP)")
                        .font(ThemeTokens.roundedNumericFont(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                .fill(ThemeTokens.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                        .strokeBorder(isCurrent ? accent.opacity(0.65) : ThemeTokens.cardStroke, lineWidth: isCurrent ? 1.5 : 1)
                )
        )
    }
}
