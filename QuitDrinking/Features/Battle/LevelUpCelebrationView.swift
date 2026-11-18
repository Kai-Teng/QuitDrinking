import SwiftUI

/// 擊敗怪獸後的晉級慶祝全螢幕覆蓋層，適合錄製 Keynote 簡報高潮轉場。
struct LevelUpCelebrationView: View {
    let defeatedMonster: MonsterSpec
    let nextMonster: MonsterSpec?
    let completedCampaign: Bool
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            ThemeTokens.canvasBackground.opacity(0.95)
                .ignoresSafeArea()

            GeometryReader { viewport in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(ThemeTokens.amberShield.opacity(0.18))
                                .frame(width: 132, height: 132)
                            Image(systemName: completedCampaign ? "crown.fill" : "trophy.fill")
                                .font(.system(size: 56, weight: .bold))
                                .foregroundStyle(ThemeTokens.amberShield)
                        }
                        .scaleEffect(appeared || reduceMotion ? 1.0 : 0.72)
                        .opacity(appeared || reduceMotion ? 1.0 : 0.0)
                        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.72), value: appeared)

                        VStack(spacing: 8) {
                            Text(completedCampaign ? "主線全破！破曉來臨" : "擊敗 Lv.\(defeatedMonster.level) 怪獸！")
                                .font(ThemeTokens.roundedTitleFont(.caption, weight: .bold))
                                .foregroundStyle(ThemeTokens.mintVitality)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(ThemeTokens.mintVitality.opacity(0.16)))

                            Text(defeatedMonster.name)
                                .font(ThemeTokens.roundedTitleFont(.largeTitle))
                                .foregroundStyle(ThemeTokens.inkPrimary)

                            Text("解鎖稱號「\(defeatedMonster.titleReward)」")
                                .font(ThemeTokens.roundedTitleFont(.title3, weight: .semibold))
                                .foregroundStyle(ThemeTokens.amberShield)
                        }

                        if let nextMonster {
                            HStack(spacing: 14) {
                                Image(systemName: nextMonster.symbolName)
                                    .font(.title2)
                                    .foregroundStyle(Color(hex: nextMonster.accentHex))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color(hex: nextMonster.accentHex).opacity(0.16)))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("下一關：Lv.\(nextMonster.level) \(nextMonster.name)")
                                        .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                                        .foregroundStyle(ThemeTokens.inkPrimary)
                                    Text("最大血量 \(nextMonster.maxHP) HP・建議目標 \(nextMonster.suggestedDays) 天")
                                        .font(.caption)
                                        .foregroundStyle(ThemeTokens.inkSecondary)
                                }
                                Spacer()
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
                            .padding(.horizontal, 24)
                        } else {
                            Text("你已征服所有飲酒心魔，隨時可到「關卡」重溫或再戰任一關卡。")
                                .font(.subheadline)
                                .foregroundStyle(ThemeTokens.inkSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Spacer()

                        Button {
                            onContinue()
                        } label: {
                            if let nextMonster {
                                Text("迎戰 Lv.\(nextMonster.level) \(nextMonster.name)")
                            } else {
                                Text("領取「破曉勇者」榮耀")
                            }
                        }
                        .buttonStyle(TactilePrimaryButtonStyle())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 12)
                    .frame(minHeight: viewport.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear {
            appeared = true
        }
    }
}
