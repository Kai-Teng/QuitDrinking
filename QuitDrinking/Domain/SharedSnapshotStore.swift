import Foundation

/// 提供主 App 與 WidgetKit 延伸共用的輕量戰鬥狀態快照。
struct BattleWidgetSnapshot: Codable, Sendable, Equatable {
    let monsterLevel: Int
    let monsterName: String
    let monsterSymbolName: String
    let currentHP: Int
    let maxHP: Int
    let currentStreak: Int
    let goalModeRaw: String
    let weeklyUsedCount: Int
    let weeklySessionLimit: Int
    let totalSavedNTD: Int
    let updatedAt: Date

    var hpRatio: Double {
        guard maxHP > 0 else { return 0 }
        return max(0, min(1, Double(currentHP) / Double(maxHP)))
    }

    var isModerationMode: Bool {
        goalModeRaw == "moderationBudget"
    }

    static let placeholder = BattleWidgetSnapshot(
        monsterLevel: 1,
        monsterName: "微醺史萊姆",
        monsterSymbolName: "drop.halffull",
        currentHP: 300,
        maxHP: 300,
        currentStreak: 0,
        goalModeRaw: "strictAbstinence",
        weeklyUsedCount: 0,
        weeklySessionLimit: 2,
        totalSavedNTD: 0,
        updatedAt: .now
    )
}

/// 負責同步與讀取 Widget 快照；當環境未配置 App Group Entitlement 時會安全降級至標準 UserDefaults。
enum SharedSnapshotStore {
    static let appGroupID = "group.com.quitdrinking.app"
    static let snapshotKey = "dawnquest.widget.snapshot.v1"

    static func save(
        _ snapshot: BattleWidgetSnapshot,
        suiteDefaults: UserDefaults? = UserDefaults(suiteName: appGroupID),
        fallbackDefaults: UserDefaults = .standard
    ) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        if let suiteDefaults {
            suiteDefaults.set(data, forKey: snapshotKey)
        }
        fallbackDefaults.set(data, forKey: snapshotKey)
    }

    static func load(
        suiteDefaults: UserDefaults? = UserDefaults(suiteName: appGroupID),
        fallbackDefaults: UserDefaults = .standard
    ) -> BattleWidgetSnapshot {
        if let data = suiteDefaults?.data(forKey: snapshotKey),
           let decoded = try? JSONDecoder().decode(BattleWidgetSnapshot.self, from: data) {
            return decoded
        }
        if let data = fallbackDefaults.data(forKey: snapshotKey),
           let decoded = try? JSONDecoder().decode(BattleWidgetSnapshot.self, from: data) {
            return decoded
        }
        return .placeholder
    }
}
