import SwiftUI

struct CampaignDetailView: View {
    let stop: CampaignStop
    let canRematch: Bool
    let enterBattle: () throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EncounterIllustration(level: stop.id, isLocked: stop.state == .locked)
                        .frame(width: 108, height: 108)
                    Text(stop.spec.situation)
                        .font(ThemeTokens.printTitleFont(.largeTitle))
                        .accessibilityAddTraits(.isHeader)
                    Text(stop.spec.subtitle)
                        .font(.body)
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("可以試試").font(.headline)
                        Text(stop.spec.alternative)
                    }
                    Divider()
                    Text(stop.spec.name).font(ThemeTokens.roundedTitleFont(.title3))
                    Label(stop.earnedTitle ? "已獲得稱號・\(stop.spec.titleReward)" : "擊敗獎勵・\(stop.spec.titleReward)",
                          systemImage: "medal.fill")
                        .font(.subheadline)
                    switch stop.state {
                    case .locked:
                        Label("擊敗 Lv.\(stop.id - 1) 怪獸後解鎖", systemImage: stop.state.symbol)
                    case .current(let hp):
                        Text("剩餘血量 \(hp) / \(stop.spec.maxHP) HP")
                            .font(ThemeTokens.roundedTitleFont(.headline)).monospacedDigit()
                        battleButton("前往戰場")
                    case .cleared:
                        if canRematch {
                            battleButton("再次挑戰")
                        } else {
                            Label("已擊敗・主線通關後可再戰", systemImage: "checkmark.seal.fill")
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(ThemeTokens.receiptInk)
            .background(ThemeTokens.receiptPaper)
            .navigationTitle("第 \(stop.id) 關・\(stop.state.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("關閉") { dismiss() } }
            }
            .alert("無法儲存再戰進度", isPresented: $saveFailed) {
                Button("好", role: .cancel) {}
            } message: { Text("請再試一次。") }
        }
        .tint(ThemeTokens.printGreen)
        .preferredColorScheme(.light)
        .presentationDragIndicator(.visible)
    }

    private func battleButton(_ title: LocalizedStringKey) -> some View {
        Button(title) {
            do { try enterBattle() } catch { saveFailed = true }
        }
        .buttonStyle(TactilePrimaryButtonStyle(fillColor: ThemeTokens.printGreen, foregroundColor: ThemeTokens.receiptPaper))
    }
}
