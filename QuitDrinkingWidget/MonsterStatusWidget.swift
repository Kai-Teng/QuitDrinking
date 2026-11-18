import WidgetKit
import SwiftUI

struct MonsterWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: BattleWidgetSnapshot
}

struct MonsterStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonsterWidgetEntry {
        MonsterWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (MonsterWidgetEntry) -> Void) {
        let entry = MonsterWidgetEntry(date: .now, snapshot: SharedSnapshotStore.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<MonsterWidgetEntry>) -> Void) {
        let entry = MonsterWidgetEntry(date: .now, snapshot: SharedSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct MonsterStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsPaper
    let entry: MonsterWidgetEntry

    private var ink: Color {
        showsPaper && renderingMode == .fullColor ? ThemeTokens.receiptInk : .primary
    }

    private var accent: Color {
        showsPaper && renderingMode == .fullColor ? ThemeTokens.printGreen : .primary
    }

    private var snapshot: BattleWidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryRectangularBody
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            savings
            Spacer(minLength: 4)
            monsterStatus
        }
    }

    private var mediumBody: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                savings
                Text("攻擊連勝 \(snapshot.currentStreak) 天")
                    .foregroundStyle(ink)
                    .font(ThemeTokens.roundedTitleFont(.caption))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(ink.opacity(0.3))
            monsterStatus
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var savings: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("估計省下的酒錢")
                .font(ThemeTokens.printTitleFont(.subheadline))
            Text("NT$ \(snapshot.totalSavedNTD.formatted())")
                .font(ThemeTokens.roundedTitleFont(.title2))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(accent)
        }
        .foregroundStyle(ink)
        .accessibilityElement(children: .combine)
    }

    private var monsterStatus: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Lv.\(snapshot.monsterLevel) \(snapshot.monsterName)")
                .font(ThemeTokens.roundedTitleFont(.subheadline))
                .monospacedDigit()
                .lineLimit(2)
            ProgressView(value: snapshot.hpRatio)
                .tint(accent)
                .accessibilityHidden(true)
            Text("\(snapshot.currentHP) / \(snapshot.maxHP) HP")
                .font(ThemeTokens.roundedTitleFont(.caption, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(ink)
        .accessibilityElement(children: .combine)
    }

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Lv.\(snapshot.monsterLevel) \(snapshot.monsterName)")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("連勝 \(snapshot.currentStreak) 天")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            ProgressView(value: snapshot.hpRatio)
            Text("HP \(snapshot.currentHP)/\(snapshot.maxHP)")
                .font(.caption2)
                .monospacedDigit()
        }
    }
}

struct MonsterStatusWidget: Widget {
    let kind = "MonsterStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonsterStatusProvider()) { entry in
            MonsterStatusWidgetView(entry: entry)
                .privacySensitive()
                .containerBackground(ThemeTokens.receiptPaper, for: .widget)
        }
        .configurationDisplayName("戒酒戰況")
        .description("查看估計省下的酒錢與怪獸剩餘血量。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
