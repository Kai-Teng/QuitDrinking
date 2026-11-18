import SwiftUI

/// All positions, including the route endpoints, share the same map coordinates.
struct CampaignTrail: View {
    let stops: [CampaignStop]
    let onSelect: (MonsterSpec) -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let points = stops.indices.map { index in
                CGPoint(x: width * (index.isMultiple(of: 2) ? 0.25 : 0.71),
                        y: height * (0.86 - 0.70 * CGFloat(index) / CGFloat(max(stops.count - 1, 1))))
            }

            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for index in points.indices.dropFirst() {
                        let from = points[index - 1]
                        let to = points[index]
                        let halfway = (from.y + to.y) / 2
                        var segment = Path()
                        segment.move(to: from)
                        segment.addCurve(to: to, control1: .init(x: from.x, y: halfway),
                                         control2: .init(x: to.x, y: halfway))
                        let reached = stops[index].state != .locked
                        let thickness = CGFloat(15 - index * 2)
                        context.stroke(segment, with: .color(ThemeTokens.canvasBackground.opacity(0.8)),
                                       style: StrokeStyle(lineWidth: thickness + 3, lineCap: .round))
                        context.stroke(segment, with: .color(reached ? ThemeTokens.mintVitality.opacity(0.85) : ThemeTokens.inkSecondary.opacity(0.6)),
                                       style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                    }
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)

                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    let point = points[index]
                    let left = index.isMultiple(of: 2)
                    let portraitWidth = min(100, width * 0.23)
                    let labelWidth = width * 0.46
                    let centerOffset = (labelWidth + 4) / 2
                    Button { onSelect(stop.spec) } label: {
                        HStack(spacing: 4) {
                            if !left { label(for: stop, alignment: .trailing, width: labelWidth) }
                            portrait(for: stop, width: portraitWidth)
                            if left { label(for: stop, alignment: .leading, width: labelWidth) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: point.x + (left ? centerOffset : -centerOffset),
                              y: point.y - portraitWidth * 0.31)
                    .accessibilityLabel("第 \(stop.id) 關，\(stop.spec.name)")
                    .accessibilityValue(accessibilityStatus(stop))
                    .accessibilityIdentifier("campaign.stop.\(stop.id)")
                    .accessibilitySortPriority(Double(stops.count - index))
                }
            }
        }
    }

    private func portrait(for stop: CampaignStop, width: CGFloat) -> some View {
        let accent = stop.state == .locked ? ThemeTokens.inkSecondary : ThemeTokens.mintVitality
        return ZStack(alignment: .bottom) {
            // The lower rim keeps the stone marker visible against the trail.
            Ellipse()
                .fill(ThemeTokens.cardSurface)
                .frame(width: width * 0.90, height: width * 0.28)
                .shadow(color: ThemeTokens.canvasBackground, radius: 3, y: 2)
            Ellipse()
                .fill(LinearGradient(colors: [accent.opacity(0.72), ThemeTokens.cardElevated],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Ellipse().strokeBorder(accent, lineWidth: 1.5))
                .frame(width: width * 0.90, height: width * 0.23)
                .padding(.bottom, width * 0.06)
            Image(decorative: "MapMonster\(stop.id)")
                .resizable().scaledToFit()
                .saturation(stop.state == .locked ? 0.1 : 1)
                .brightness(stop.state == .locked ? -0.20 : 0)
                .padding(.bottom, width * 0.10)
        }
        .frame(width: width, height: width * 0.90, alignment: .bottom)
    }

    private func label(for stop: CampaignStop, alignment: HorizontalAlignment, width: CGFloat) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text("Lv.\(stop.id)")
                .font(ThemeTokens.roundedTitleFont(.caption, weight: .bold))
                .monospacedDigit()
            Text(stop.spec.name)
                .font(ThemeTokens.roundedTitleFont(.headline))
            Label(stop.state.label, systemImage: stop.state.symbol)
                .font(.caption.bold())
                .foregroundStyle(stop.state == .locked ? ThemeTokens.inkPrimary : ThemeTokens.mintVitality)
            if case let .current(hp) = stop.state {
                ProgressView(value: Double(hp), total: Double(stop.spec.maxHP))
                    .tint(ThemeTokens.mintVitality).frame(maxWidth: 98)
                Text("\(hp) / \(stop.spec.maxHP) HP")
                    .font(ThemeTokens.roundedTitleFont(.caption, weight: .medium))
                    .monospacedDigit()
            }
        }
        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(ThemeTokens.canvasBackground.opacity(0.78), in: .rect(cornerRadius: 10))
        .frame(width: width, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func accessibilityStatus(_ stop: CampaignStop) -> String {
        if case let .current(hp) = stop.state {
            return "\(stop.state.label)，剩餘 \(hp) / \(stop.spec.maxHP) HP"
        }
        return stop.state.label
    }
}
