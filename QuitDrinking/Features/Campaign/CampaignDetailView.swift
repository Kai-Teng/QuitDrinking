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
                VStack(alignment: .leading, spacing: 18) {
                    Image(decorative: "MapMonster\(stop.id)")
                        .resizable().scaledToFit()
                        .saturation(stop.state == .locked ? 0 : 1)
                        .frame(height: 104)
                        .frame(maxWidth: .infinity)
                    Text(stop.spec.name)
                        .font(ThemeTokens.roundedTitleFont(.title))
                    Text(stop.spec.subtitle)
                    Label(stop.earnedTitle ? "已獲得稱號・\(stop.spec.titleReward)" : "擊敗獎勵・\(stop.spec.titleReward)",
                          systemImage: "medal.fill")
                        .foregroundStyle(stop.earnedTitle ? ThemeTokens.amberShield : ThemeTokens.inkSecondary)

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
            .foregroundStyle(ThemeTokens.inkPrimary)
            .background(ThemeTokens.canvasBackground)
            .navigationTitle("Lv.\(stop.id)・\(stop.state.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .alert("無法儲存再戰進度", isPresented: $saveFailed) {
                Button("好", role: .cancel) {}
            } message: {
                Text("請再試一次。")
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func battleButton(_ title: LocalizedStringKey) -> some View {
        Button(title) {
            do { try enterBattle() } catch { saveFailed = true }
        }
        .buttonStyle(TactilePrimaryButtonStyle())
    }
}
