import SwiftUI

struct CampaignTrail: View {
    let stops: [CampaignStop]
    let onSelect: (MonsterSpec) -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let nodes = stops.indices.map { index in
                CGPoint(x: width * (index.isMultiple(of: 2) ? 0.22 : 0.78),
                        y: height * (0.86 - 0.72 * CGFloat(index) / CGFloat(max(stops.count - 1, 1))))
            }
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    // Two creases in the unfolded paper, underneath the printed route.
                    for fraction in [0.34, 0.68] {
                        var crease = Path()
                        crease.move(to: CGPoint(x: size.width * fraction, y: 0))
                        crease.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
                        context.stroke(crease, with: .color(ThemeTokens.receiptInk.opacity(0.08)), lineWidth: 1)
                    }
                    for index in nodes.indices.dropFirst() {
                        let from = nodes[index - 1]
                        let to = nodes[index]
                        let midway = (from.y + to.y) / 2
                        var path = Path()
                        path.move(to: from)
                        path.addCurve(to: to, control1: CGPoint(x: from.x, y: midway),
                                      control2: CGPoint(x: to.x, y: midway))
                        let locked = stops[index].state == .locked
                        context.stroke(path, with: .color(locked ? ThemeTokens.receiptInk.opacity(0.45) : ThemeTokens.printGreen),
                                       style: StrokeStyle(lineWidth: locked ? 2 : 3, lineCap: .round,
                                                          dash: locked ? [2, 6] : []))
                    }
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)

                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    let node = nodes[index]
                    let left = index.isMultiple(of: 2)
                    let diameter = min(107, width * 0.245)
                    let labelWidth = width * 0.51
                    let offset = (labelWidth + 8) / 2
                    Button { onSelect(stop.spec) } label: {
                        HStack(spacing: 8) {
                            if !left { label(for: stop, leftAligned: false, width: labelWidth) }
                            EncounterIllustration(level: stop.id, isLocked: stop.state == .locked)
                                .frame(width: diameter, height: diameter)
                                .rotationEffect(.degrees(left ? -5 : 4))
                            if left { label(for: stop, leftAligned: true, width: labelWidth) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: node.x + (left ? offset : -offset), y: node.y)
                    .accessibilityLabel("第 \(stop.id) 關，\(stop.spec.situation)，\(stop.spec.name)")
                    .accessibilityValue(accessibilityStatus(stop))
                    .accessibilityIdentifier("campaign.stop.\(stop.id)")
                    .accessibilitySortPriority(Double(stops.count - index))
                }
            }
        }
    }

    private func label(for stop: CampaignStop, leftAligned: Bool, width: CGFloat) -> some View {
        let alignment: HorizontalAlignment = leftAligned ? .leading : .trailing
        return VStack(alignment: alignment, spacing: 3) {
            Label("第 \(stop.id) 關・\(stop.state.label)", systemImage: stop.state.symbol)
                .font(ThemeTokens.roundedTitleFont(.caption, weight: .semibold))
                .foregroundStyle(ThemeTokens.printGreen)
            Text(stop.spec.situation)
                .font(ThemeTokens.printTitleFont(.title2))
            Text(stop.spec.name)
                .font(.subheadline)
            if case .current(let hp) = stop.state {
                Text("\(hp) / \(stop.spec.maxHP) HP")
                    .font(ThemeTokens.roundedTitleFont(.caption)).monospacedDigit()
                ProgressView(value: Double(hp), total: Double(stop.spec.maxHP))
                    .tint(ThemeTokens.printGreen)
                    .frame(width: 90)
                    .environment(\.colorScheme, .light)
            }
        }
        .multilineTextAlignment(leftAligned ? .leading : .trailing)
        .padding(.vertical, 2)
        .background(ThemeTokens.receiptPaper)
        .frame(width: width, alignment: leftAligned ? .leading : .trailing)
    }

    private func accessibilityStatus(_ stop: CampaignStop) -> String {
        if case let .current(hp) = stop.state { return "\(stop.state.label)，剩餘 \(hp) / \(stop.spec.maxHP) HP" }
        return stop.state.label
    }
}
