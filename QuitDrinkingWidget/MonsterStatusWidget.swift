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
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct MonsterStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MonsterWidgetEntry

    private var snapshot: BattleWidgetSnapshot { entry.snapshot }

    private var hpTint: Color {
        if snapshot.hpRatio > 0.40 { return ThemeTokens.mintVitality }
        if snapshot.hpRatio > 0.20 { return ThemeTokens.amberShield }
        return ThemeTokens.coralAlert
    }

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lv.\(snapshot.monsterLevel)")
                    .font(ThemeTokens.roundedTitleFont(.caption2, weight: .bold))
                    .foregroundStyle(ThemeTokens.canvasBackground)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(hpTint))
                Spacer()
                Image(systemName: snapshot.monsterSymbolName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(hpTint)
            }

            Text(snapshot.monsterName)
                .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                .foregroundStyle(ThemeTokens.inkPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: snapshot.hpRatio)
                    .tint(hpTint)
                Text("HP \(snapshot.currentHP)/\(snapshot.maxHP)")
                    .font(ThemeTokens.roundedNumericFont(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ThemeTokens.inkSecondary)
            }
        }
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(hpTint.opacity(0.16))
                    .frame(width: 78, height: 78)
                Image(systemName: snapshot.monsterSymbolName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(hpTint)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Lv.\(snapshot.monsterLevel) \(snapshot.monsterName)")
                        .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
                        .foregroundStyle(ThemeTokens.inkPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("連勝 \(snapshot.currentStreak) 天")
                        .font(ThemeTokens.roundedTitleFont(.caption2, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(ThemeTokens.mintVitality)
                }

                ProgressView(value: snapshot.hpRatio)
                    .tint(hpTint)

                HStack {
                    Text("HP \(snapshot.currentHP) / \(snapshot.maxHP)")
                        .font(ThemeTokens.roundedNumericFont(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(ThemeTokens.inkPrimary)
                    Spacer()
                    Text("已省 NT$ \(snapshot.totalSavedNTD)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(ThemeTokens.amberShield)
                }
            }
        }
    }

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Lv.\(snapshot.monsterLevel) \(snapshot.monsterName)")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(snapshot.currentStreak)d")
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
                .containerBackground(ThemeTokens.canvasBackground, for: .widget)
        }
        .configurationDisplayName("破曉戰記怪獸狀態")
        .description("在主畫面與鎖定畫面追蹤目前怪獸血量與清醒連勝。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
