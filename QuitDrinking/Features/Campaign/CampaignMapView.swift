import SwiftUI

struct CampaignMapView: View {
    let progress: PlayerProgress
    let onOpenBattle: () -> Void
    let onRematch: (Int) throws -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var minimumTrailHeight = 420.0
    @State private var selection: MonsterSpec?

    var body: some View {
        let stops = CampaignStop.all(for: progress)
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("飲酒情境地圖")
                            .font(ThemeTokens.printTitleFont(.largeTitle))
                            .accessibilityAddTraits(.isHeader)
                        Text("已通過 \(stops.filter(\.earnedTitle).count) / \(stops.count) 關")
                            .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .medium))
                            .monospacedDigit()
                        Rectangle().frame(height: 2).accessibilityHidden(true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                    if typeSize >= .xxxLarge || viewport.size.width < 320 {
                        ForEach(stops) { stop in
                            Button { selection = stop.spec } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Label("第 \(stop.id) 關・\(stop.state.label)", systemImage: stop.state.symbol)
                                        .font(.subheadline)
                                    Text(stop.spec.situation)
                                        .font(ThemeTokens.printTitleFont(.title2))
                                    Text(stop.spec.name)
                                    if case .current(let hp) = stop.state {
                                        Text("\(hp) / \(stop.spec.maxHP) HP").monospacedDigit()
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("campaign.stop.\(stop.id)")
                            Divider().overlay(ThemeTokens.receiptInk.opacity(0.35))
                        }
                        .padding(.horizontal, 22)
                    } else {
                        CampaignTrail(stops: stops) { selection = $0 }
                            .frame(height: max(minimumTrailHeight, min(680, viewport.size.height - 205)))
                    }

                    if let current = stops.first(where: { if case .current = $0.state { true } else { false } }) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("這一關可以試試")
                                .font(ThemeTokens.roundedTitleFont(.subheadline))
                            Text(current.spec.alternative)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) {
                            Rectangle().fill(ThemeTokens.receiptInk.opacity(0.5)).frame(height: 1)
                        }
                        .padding(.horizontal, 22)
                    }
                }
                .padding(.bottom, 15)
                .foregroundStyle(ThemeTokens.receiptInk)
                .frame(maxWidth: 660)
                .background(ThemeTokens.receiptPaper)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(ThemeTokens.canvasBackground.ignoresSafeArea())
        .sheet(item: $selection) { spec in
            if let stop = stops.first(where: { $0.spec == spec }) {
                CampaignDetailView(stop: stop, canRematch: progress.hasCompletedCampaign) {
                    if stop.state == .cleared { try onRematch(spec.level) }
                    selection = nil
                    onOpenBattle()
                }
            }
        }
    }
}
