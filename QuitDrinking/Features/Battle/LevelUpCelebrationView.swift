import SwiftUI

/// 晉級時蓋下這一關的完成章，保留可捲動的紙本紀錄。
struct LevelUpCelebrationView: View {
    let defeatedMonster: MonsterSpec
    let nextMonster: MonsterSpec?
    let completedCampaign: Bool
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(completedCampaign ? "四關完成" : "第 \(defeatedMonster.level) 關完成")
                            .font(.system(.title, design: .serif, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 8)
                        Image(systemName: "checkmark.seal")
                            .font(.largeTitle)
                            .foregroundStyle(ThemeTokens.printGreen)
                            .rotationEffect(.degrees(-8))
                            .scaleEffect(appeared || reduceMotion ? 1 : 1.25)
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: appeared)
                            .accessibilityHidden(true)
                    }
                    Divider().overlay(ThemeTokens.receiptInk.opacity(0.35))
                    Text(defeatedMonster.situation)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                    Text("擊敗\(defeatedMonster.name)，獲得「\(defeatedMonster.titleReward)」。")
                        .font(.headline)
                    if let nextMonster {
                        Divider().overlay(ThemeTokens.receiptInk.opacity(0.35))
                        Text("下一關・\(nextMonster.situation)")
                            .font(.headline)
                        Text(nextMonster.subtitle)
                            .font(.subheadline)
                        Text("\(nextMonster.name)　\(nextMonster.maxHP) HP")
                            .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .medium))
                            .monospacedDigit()
                    } else {
                        Text("你的每一筆打卡都已留下。之後可以從關卡地圖選一個情境再挑戰。")
                    }
                    Button(action: onContinue) {
                        if let nextMonster {
                            Text("迎戰 Lv.\(nextMonster.level) \(nextMonster.name)")
                        } else {
                            Text("領取「破曉勇者」榮耀")
                        }
                    }
                    .buttonStyle(TactilePrimaryButtonStyle(fillColor: ThemeTokens.printGreen,
                                                         foregroundColor: ThemeTokens.receiptPaper))
                }
                .padding(24)
                .foregroundStyle(ThemeTokens.receiptInk)
                .background(ThemeTokens.receiptPaper, in: .rect(cornerRadius: 4))
                .frame(maxWidth: 520)
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: viewport.size.height)
            }
        }
        .background(ThemeTokens.canvasBackground.ignoresSafeArea())
        .onAppear { appeared = true }
    }
}
