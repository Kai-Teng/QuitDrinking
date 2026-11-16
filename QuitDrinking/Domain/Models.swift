import Foundation
import SwiftData

/// 戒酒／減量雙軌模式。
enum GoalMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case strictAbstinence
    case moderationBudget

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strictAbstinence: "完全斷酒"
        case .moderationBudget: "減量控酒"
        }
    }

    var shortBadgeTitle: String {
        switch self {
        case .strictAbstinence: "完全斷酒"
        case .moderationBudget: "減量"
        }
    }

    var subtitle: String {
        switch self {
        case .strictAbstinence: "每日滴酒不沾即可重擊怪獸，喝了則開啟誠實護盾"
        case .moderationBudget: "設定每週理性次數額度，額度內小酌不中斷連勝"
        }
    }
}

/// 每日戰役打卡結果類型。
enum CheckInOutcomeType: String, Codable, Sendable {
    case soberAttack
    case withinBudgetDrink
    case honestShieldRelapse

    var displayTitle: String {
        switch self {
        case .soberAttack: "清醒攻擊"
        case .withinBudgetDrink: "額度內小酌"
        case .honestShieldRelapse: "誠實護盾"
        }
    }
}

/// 誠實護盾誘因情境標籤。
enum RelapseTriggerTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case socialGathering = "聚餐應酬"
    case workStress = "工作課業壓力"
    case peerPressure = "朋友起鬨"
    case lowMood = "心情低落"
    case celebration = "慶祝開心"
    case bedtimeHabit = "睡前習慣"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .socialGathering: "person.3.fill"
        case .workStress: "briefcase.fill"
        case .peerPressure: "party.popper.fill"
        case .lowMood: "cloud.rain.fill"
        case .celebration: "sparkles"
        case .bedtimeHabit: "moon.stars.fill"
        }
    }
}

/// 玩家持久化遊戲進度。
@Model
final class PlayerProgress {
    var id: UUID
    var goalModeRaw: String
    var weeklySessionLimit: Int
    var activeMonsterLevel: Int
    var currentMonsterHP: Int
    var currentStreak: Int
    var totalCleanCheckIns: Int
    var totalDamageDealt: Int
    var totalMonstersDefeated: Int
    var defeatedMonsterLevelsRaw: String
    var honestShieldCount: Int
    var insightXP: Int
    var hasCompletedCampaign: Bool
    var costPerDrinkNTD: Int
    var caloriesPerDrink: Int
    var virtualDayOffset: Int
    var demoRapidMode: Bool
    var pureRecordingMode: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        goalMode: GoalMode = .strictAbstinence,
        weeklySessionLimit: Int = 2,
        activeMonsterLevel: Int = 1,
        currentMonsterHP: Int = 300,
        currentStreak: Int = 0,
        totalCleanCheckIns: Int = 0,
        totalDamageDealt: Int = 0,
        totalMonstersDefeated: Int = 0,
        defeatedMonsterLevels: Set<Int> = [],
        honestShieldCount: Int = 0,
        insightXP: Int = 0,
        hasCompletedCampaign: Bool = false,
        costPerDrinkNTD: Int = 250,
        caloriesPerDrink: Int = 420,
        virtualDayOffset: Int = 0,
        demoRapidMode: Bool = true,
        pureRecordingMode: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.goalModeRaw = goalMode.rawValue
        self.weeklySessionLimit = max(1, min(4, weeklySessionLimit))
        self.activeMonsterLevel = activeMonsterLevel
        self.currentMonsterHP = currentMonsterHP
        self.currentStreak = currentStreak
        self.totalCleanCheckIns = totalCleanCheckIns
        self.totalDamageDealt = totalDamageDealt
        self.totalMonstersDefeated = totalMonstersDefeated
        self.defeatedMonsterLevelsRaw = Self.encodeLevels(defeatedMonsterLevels)
        self.honestShieldCount = honestShieldCount
        self.insightXP = insightXP
        self.hasCompletedCampaign = hasCompletedCampaign
        self.costPerDrinkNTD = costPerDrinkNTD
        self.caloriesPerDrink = caloriesPerDrink
        self.virtualDayOffset = virtualDayOffset
        self.demoRapidMode = demoRapidMode
        self.pureRecordingMode = pureRecordingMode
        self.createdAt = createdAt
    }

    var goalMode: GoalMode {
        get { GoalMode(rawValue: goalModeRaw) ?? .strictAbstinence }
        set { goalModeRaw = newValue.rawValue }
    }

    var defeatedMonsterLevels: Set<Int> {
        get {
            let values = defeatedMonsterLevelsRaw
                .split(separator: ",")
                .compactMap { Int($0) }
            return Set(values)
        }
        set {
            defeatedMonsterLevelsRaw = Self.encodeLevels(newValue)
        }
    }

    private static func encodeLevels(_ levels: Set<Int>) -> String {
        levels.sorted().map(String.init).joined(separator: ",")
    }
}

/// 單日戰役打卡紀錄。
@Model
final class CheckInRecord {
    var id: UUID
    var simulatedDate: Date
    var createdAt: Date
    var outcomeRaw: String
    var hpDelta: Int
    var monsterLevel: Int
    var drinkUnits: Int
    var triggerTagsRaw: String
    var note: String

    init(
        id: UUID = UUID(),
        simulatedDate: Date,
        createdAt: Date = .now,
        outcome: CheckInOutcomeType,
        hpDelta: Int,
        monsterLevel: Int,
        drinkUnits: Int = 0,
        triggers: [RelapseTriggerTag] = [],
        note: String = ""
    ) {
        self.id = id
        self.simulatedDate = simulatedDate
        self.createdAt = createdAt
        self.outcomeRaw = outcome.rawValue
        self.hpDelta = hpDelta
        self.monsterLevel = monsterLevel
        self.drinkUnits = drinkUnits
        self.triggerTagsRaw = triggers.map(\.rawValue).joined(separator: ",")
        self.note = note
    }

    var outcome: CheckInOutcomeType {
        get { CheckInOutcomeType(rawValue: outcomeRaw) ?? .soberAttack }
        set { outcomeRaw = newValue.rawValue }
    }

    var triggers: [RelapseTriggerTag] {
        get {
            triggerTagsRaw
                .split(separator: ",")
                .compactMap { RelapseTriggerTag(rawValue: String($0)) }
        }
        set {
            triggerTagsRaw = newValue.map(\.rawValue).joined(separator: ",")
        }
    }
}
