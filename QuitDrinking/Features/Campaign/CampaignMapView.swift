import SwiftUI

struct CampaignMapView: View {
    let progress: PlayerProgress
    let onOpenBattle: () -> Void
    let onRematch: (Int) throws -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selection: MonsterSpec?

    var body: some View {
        let stops = CampaignStop.all(for: progress)
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("關卡")
                            .font(ThemeTokens.roundedTitleFont(.largeTitle))
                            .accessibilityAddTraits(.isHeader)
                        Text("已擊敗 \(stops.filter(\.earnedTitle).count) / \(stops.count)")
                            .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .medium))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .shadow(color: ThemeTokens.canvasBackground, radius: 4)

                    if typeSize >= .xxxLarge || proxy.size.width < 320 {
                        VStack(spacing: 14) {
                            ForEach(stops) { stop in
                                Button { selection = stop.spec } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label("Lv.\(stop.id) \(stop.spec.name)・\(stop.state.label)",
                                              systemImage: stop.state.symbol)
                                        if case .current(let hp) = stop.state {
                                            Text("\(hp) / \(stop.spec.maxHP) HP")
                                                .font(ThemeTokens.roundedTitleFont(.subheadline))
                                                .monospacedDigit()
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(TactileOutlineButtonStyle(accentColor: ThemeTokens.inkPrimary))
                                .accessibilityIdentifier("campaign.stop.\(stop.id)")
                            }
                        }
                        .padding(20)
                    } else {
                        CampaignTrail(stops: stops) { selection = $0 }
                            .frame(height: max(480, proxy.size.height - 90))
                    }
                }
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .foregroundStyle(ThemeTokens.inkPrimary)
            .background {
                GeometryReader { backdrop in
                    Image(decorative: "CampaignValley")
                        .resizable()
                        .scaledToFill()
                        .frame(width: backdrop.size.width, height: backdrop.size.height)
                        .clipped()
                        .overlay(ThemeTokens.canvasBackground.opacity(0.18))
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
        }
        .background(ThemeTokens.canvasBackground.ignoresSafeArea())
        .sheet(item: $selection) { spec in
            if let stop = stops.first(where: { $0.spec == spec }) {
                CampaignDetailView(stop: stop, canRematch: progress.hasCompletedCampaign) {
                    if stop.state == .cleared {
                        try onRematch(spec.level)
                    }
                    selection = nil
                    onOpenBattle()
                }
            }
        }
    }
}
