import Foundation
import SwiftData

/// MAIC 簡報錄影用一鍵狀態預設。
enum MAICDemoPreset: String, CaseIterable, Identifiable, Sendable {
    case freshStart
    case nearVictory
    case shieldStandby
    case richWeekHistory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freshStart: "初登場：Lv.1 滿血狀態"
        case .nearVictory: "精彩時刻：Lv.2 殘血待斬"
        case .shieldStandby: "防棄坑演示：誠實護盾待命"
        case .richWeekHistory: "成果豐富態：一週實戰數據"
        }
    }

    var subtitle: String {
        switch self {
        case .freshStart: "Lv.1 微醺史萊姆 300/300 HP・準備展示第一擊"
        case .nearVictory: "Lv.2 哥布林僅剩 90 HP・點一下「今日沒喝」立刻晉級"
        case .shieldStandby: "減量額度已滿 2/2・按「今天有喝」示範誠實護盾特效"
        case .richWeekHistory: "Lv.3 宿醉巨龍＋7 天完整圖表與誘因洞察資料"
        }
    }
}

/// 打卡動作回傳結果，供 View 觸發對應動效與覆蓋層。
enum CombatActionStatus: Equatable, Sendable {
    case applied(CombatActionSummary)
    case alreadyCheckedInToday
    case campaignStandbyRequiresRematch
}

struct CombatActionSummary: Equatable, Sendable {
    let outcome: CheckInOutcomeType
    let hpDelta: Int
    let defeatedMonster: MonsterSpec?
    let promotedToMonster: MonsterSpec?
    let completedCampaign: Bool
    let didAdvanceVirtualDay: Bool
    let recordDate: Date
}

struct ImpactMetrics: Equatable, Sendable {
    let totalSavedNTD: Int
    let totalCaloriesAvoided: Int
    let riceBowlsEquivalent: Double
}

struct DailyChartBucket: Identifiable, Equatable, Sendable {
    let date: Date
    let dayLabel: String
    let outcome: CheckInOutcomeType?
    let magnitude: Int

    var id: Date { date }
}

struct TriggerStatItem: Identifiable, Equatable, Sendable {
    let tag: RelapseTriggerTag
    let count: Int
    let ratio: Double

    var id: RelapseTriggerTag { tag }
}

/// 負責所有純數值運算、防懲罰規則、減量週額度與 Demo 模擬時間軸的戰鬥引擎。
enum CombatEngine {
    static let baseAttackDamage = 100
    static let streakBonusPerDay = 10
    static let maxStreakBonus = 50
    static let insightXPPerShield = 25
    static let kcalPerRiceBowl = 280.0

    // MARK: - Calendar & Virtual Clock

    private static func mondayCalendar(basedOn calendar: Calendar) -> Calendar {
        var copy = calendar
        copy.firstWeekday = 2
        return copy
    }

    static func effectiveToday(
        for progress: PlayerProgress,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: progress.virtualDayOffset, to: startOfToday) ?? startOfToday
    }

    static func hasRecord(
        on day: Date,
        records: [CheckInRecord],
        calendar: Calendar = .current
    ) -> Bool {
        records.contains { calendar.isDate($0.simulatedDate, inSameDayAs: day) }
    }

    private static func resolveTargetDay(
        for progress: PlayerProgress,
        records: [CheckInRecord],
        now: Date,
        calendar: Calendar
    ) -> (day: Date, didAdvance: Bool)? {
        let currentDay = effectiveToday(for: progress, now: now, calendar: calendar)
        if !hasRecord(on: currentDay, records: records, calendar: calendar) {
            return (currentDay, false)
        }
        guard progress.demoRapidMode else {
            return nil
        }

        var candidate = currentDay
        while hasRecord(on: candidate, records: records, calendar: calendar) {
            progress.virtualDayOffset += 1
            candidate = effectiveToday(for: progress, now: now, calendar: calendar)
        }
        return (candidate, true)
    }

    // MARK: - Weekly Moderation Budget

    static func weeklyDrinksUsed(
        on referenceDay: Date,
        records: [CheckInRecord],
        calendar: Calendar = .current
    ) -> Int {
        let iso = mondayCalendar(basedOn: calendar)
        guard let weekInterval = iso.dateInterval(of: .weekOfYear, for: referenceDay) else {
            return 0
        }
        return records.filter { record in
            guard weekInterval.contains(record.simulatedDate) else { return false }
            return record.outcome == .withinBudgetDrink || record.outcome == .honestShieldRelapse
        }.count
    }

    static func currentWeeklyDrinksUsed(
        progress: PlayerProgress,
        records: [CheckInRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let day = effectiveToday(for: progress, now: now, calendar: calendar)
        return weeklyDrinksUsed(on: day, records: records, calendar: calendar)
    }

    /// 預測使用者若現在點選「今天有喝」是否會觸發誠實護盾（供表單與 UI 即時預覽）。
    static func willTriggerHonestShieldOnDrink(
        progress: PlayerProgress,
        records: [CheckInRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        if progress.goalMode == .strictAbstinence {
            return true
        }
        var targetDay = effectiveToday(for: progress, now: now, calendar: calendar)
        if progress.demoRapidMode && hasRecord(on: targetDay, records: records, calendar: calendar) {
            var offset = progress.virtualDayOffset
            let base = calendar.startOfDay(for: now)
            while hasRecord(on: targetDay, records: records, calendar: calendar) {
                offset += 1
                targetDay = calendar.date(byAdding: .day, value: offset, to: base) ?? targetDay
            }
        }
        let used = weeklyDrinksUsed(on: targetDay, records: records, calendar: calendar)
        return used >= progress.weeklySessionLimit
    }

    // MARK: - Damage & Heal Math

    static func previewAttackDamage(for progress: PlayerProgress) -> Int {
        let bonus = min(max(0, progress.currentStreak) * streakBonusPerDay, maxStreakBonus)
        return baseAttackDamage + bonus
    }

    static func honestShieldHealAmount(units: Int, monsterMaxHP: Int) -> Int {
        let clampedUnits = max(1, units)
        let cap = Int(Double(monsterMaxHP) * 0.20)
        return min(clampedUnits * 45, max(1, cap))
    }

    static func withinBudgetHealAmount(units: Int, monsterMaxHP: Int) -> Int {
        let clampedUnits = max(1, units)
        let cap = Int(Double(monsterMaxHP) * 0.10)
        return min(clampedUnits * 15, max(1, cap))
    }

    static func impactSummary(for progress: PlayerProgress) -> ImpactMetrics {
        let saved = progress.totalCleanCheckIns * progress.costPerDrinkNTD
        let kcal = progress.totalCleanCheckIns * progress.caloriesPerDrink
        return ImpactMetrics(
            totalSavedNTD: saved,
            totalCaloriesAvoided: kcal,
            riceBowlsEquivalent: Double(kcal) / kcalPerRiceBowl
        )
    }

    // MARK: - Combat Actions

    static func isCampaignVictoryStandby(_ progress: PlayerProgress) -> Bool {
        progress.hasCompletedCampaign && progress.activeMonsterLevel == 4 && progress.currentMonsterHP == 0
    }

    @MainActor
    static func logSoberAttack(
        progress: PlayerProgress,
        records: [CheckInRecord],
        insertRecord: (CheckInRecord) -> Void,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CombatActionStatus {
        if isCampaignVictoryStandby(progress) {
            return .campaignStandbyRequiresRematch
        }
        guard let resolved = resolveTargetDay(for: progress, records: records, now: now, calendar: calendar) else {
            return .alreadyCheckedInToday
        }

        let currentSpec = MonsterCatalog.spec(forLevel: progress.activeMonsterLevel)
        let damage = previewAttackDamage(for: progress)
        let newHP = max(0, progress.currentMonsterHP - damage)

        progress.currentStreak += 1
        progress.totalCleanCheckIns += 1
        progress.totalDamageDealt += damage

        let record = CheckInRecord(
            simulatedDate: resolved.day,
            createdAt: now,
            outcome: .soberAttack,
            hpDelta: -damage,
            monsterLevel: currentSpec.level
        )
        insertRecord(record)

        var defeated: MonsterSpec?
        var promotedTo: MonsterSpec?
        var completedCampaignNow = false

        if newHP == 0 {
            defeated = currentSpec
            progress.totalMonstersDefeated += 1
            var defeatedSet = progress.defeatedMonsterLevels
            defeatedSet.insert(currentSpec.level)
            progress.defeatedMonsterLevels = defeatedSet

            if currentSpec.level < MonsterCatalog.all.count {
                let next = MonsterCatalog.spec(forLevel: currentSpec.level + 1)
                progress.activeMonsterLevel = next.level
                progress.currentMonsterHP = next.maxHP
                promotedTo = next
            } else {
                progress.hasCompletedCampaign = true
                progress.currentMonsterHP = 0
                completedCampaignNow = true
            }
        } else {
            progress.currentMonsterHP = newHP
        }

        syncSnapshot(progress: progress, records: records + [record], now: now, calendar: calendar)

        return .applied(
            CombatActionSummary(
                outcome: .soberAttack,
                hpDelta: -damage,
                defeatedMonster: defeated,
                promotedToMonster: promotedTo,
                completedCampaign: completedCampaignNow,
                didAdvanceVirtualDay: resolved.didAdvance,
                recordDate: resolved.day
            )
        )
    }

    @MainActor
    static func logDrink(
        progress: PlayerProgress,
        records: [CheckInRecord],
        units: Int,
        triggers: [RelapseTriggerTag],
        note: String,
        insertRecord: (CheckInRecord) -> Void,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CombatActionStatus {
        if isCampaignVictoryStandby(progress) {
            return .campaignStandbyRequiresRematch
        }
        guard let resolved = resolveTargetDay(for: progress, records: records, now: now, calendar: calendar) else {
            return .alreadyCheckedInToday
        }

        let currentSpec = MonsterCatalog.spec(forLevel: progress.activeMonsterLevel)
        let usedBefore = weeklyDrinksUsed(on: resolved.day, records: records, calendar: calendar)
        let triggersShield = (progress.goalMode == .strictAbstinence) || (usedBefore >= progress.weeklySessionLimit)

        let outcome: CheckInOutcomeType
        let healAmount: Int
        let sanitizedTriggers: [RelapseTriggerTag]

        if triggersShield {
            outcome = .honestShieldRelapse
            healAmount = honestShieldHealAmount(units: units, monsterMaxHP: currentSpec.maxHP)
            sanitizedTriggers = triggers.isEmpty ? [.socialGathering] : triggers
            progress.currentStreak = 0
            progress.honestShieldCount += 1
            progress.insightXP += insightXPPerShield
        } else {
            outcome = .withinBudgetDrink
            healAmount = withinBudgetHealAmount(units: units, monsterMaxHP: currentSpec.maxHP)
            sanitizedTriggers = triggers
        }

        progress.currentMonsterHP = min(currentSpec.maxHP, progress.currentMonsterHP + healAmount)

        let record = CheckInRecord(
            simulatedDate: resolved.day,
            createdAt: now,
            outcome: outcome,
            hpDelta: healAmount,
            monsterLevel: currentSpec.level,
            drinkUnits: max(1, units),
            triggers: sanitizedTriggers,
            note: note
        )
        insertRecord(record)
        syncSnapshot(progress: progress, records: records + [record], now: now, calendar: calendar)

        return .applied(
            CombatActionSummary(
                outcome: outcome,
                hpDelta: healAmount,
                defeatedMonster: nil,
                promotedToMonster: nil,
                completedCampaign: false,
                didAdvanceVirtualDay: resolved.didAdvance,
                recordDate: resolved.day
            )
        )
    }

    @MainActor
    static func rematchMonster(
        level: Int,
        progress: PlayerProgress,
        records: [CheckInRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        let targetSpec = MonsterCatalog.spec(forLevel: level)
        progress.activeMonsterLevel = targetSpec.level
        progress.currentMonsterHP = targetSpec.maxHP
        syncSnapshot(progress: progress, records: records, now: now, calendar: calendar)
    }

    // MARK: - Analytics Helpers

    static func recentSevenDayBuckets(
        progress: PlayerProgress,
        records: [CheckInRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyChartBucket] {
        let today = effectiveToday(for: progress, now: now, calendar: calendar)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "M/d"

        return (-6...0).compactMap { delta in
            guard let day = calendar.date(byAdding: .day, value: delta, to: today) else { return nil }
            let dayRecords = records.filter { calendar.isDate($0.simulatedDate, inSameDayAs: day) }
            let label = delta == 0 ? "今日" : formatter.string(from: day)
            guard let dominant = dayRecords.last else {
                return DailyChartBucket(date: day, dayLabel: label, outcome: nil, magnitude: 0)
            }
            let magnitude = dominant.outcome == .soberAttack
                ? max(10, abs(dominant.hpDelta))
                : max(20, dominant.hpDelta)
            return DailyChartBucket(date: day, dayLabel: label, outcome: dominant.outcome, magnitude: magnitude)
        }
    }

    static func triggerBreakdown(from records: [CheckInRecord]) -> [TriggerStatItem] {
        let shieldRecords = records.filter { $0.outcome == .honestShieldRelapse }
        var counts: [RelapseTriggerTag: Int] = [:]
        var total = 0
        for record in shieldRecords {
            for tag in record.triggers {
                counts[tag, default: 0] += 1
                total += 1
            }
        }
        guard total > 0 else { return [] }
        return counts
            .map { TriggerStatItem(tag: $0.key, count: $0.value, ratio: Double($0.value) / Double(total)) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.tag.rawValue < rhs.tag.rawValue
            }
    }

    // MARK: - Widget Sync & Demo Presets

    @MainActor
    static func syncSnapshot(
        progress: PlayerProgress,
        records: [CheckInRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        let spec = MonsterCatalog.spec(forLevel: progress.activeMonsterLevel)
        let used = currentWeeklyDrinksUsed(progress: progress, records: records, now: now, calendar: calendar)
        let snapshot = BattleWidgetSnapshot(
            monsterLevel: spec.level,
            monsterName: spec.name,
            monsterSymbolName: spec.symbolName,
            currentHP: progress.currentMonsterHP,
            maxHP: spec.maxHP,
            currentStreak: progress.currentStreak,
            goalModeRaw: progress.goalMode.rawValue,
            weeklyUsedCount: used,
            weeklySessionLimit: progress.weeklySessionLimit,
            totalSavedNTD: impactSummary(for: progress).totalSavedNTD,
            updatedAt: now
        )
        SharedSnapshotStore.save(snapshot)
    }

    @MainActor
    static func applyDemoPreset(
        _ preset: MAICDemoPreset,
        progress: PlayerProgress,
        existingRecords: [CheckInRecord],
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        for record in existingRecords {
            context.delete(record)
        }

        let today = calendar.startOfDay(for: now)
        var seeded: [CheckInRecord] = []

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        switch preset {
        case .freshStart:
            progress.goalMode = .strictAbstinence
            progress.weeklySessionLimit = 2
            progress.activeMonsterLevel = 1
            progress.currentMonsterHP = 300
            progress.currentStreak = 0
            progress.totalCleanCheckIns = 0
            progress.totalDamageDealt = 0
            progress.totalMonstersDefeated = 0
            progress.defeatedMonsterLevels = []
            progress.honestShieldCount = 0
            progress.insightXP = 0
            progress.hasCompletedCampaign = false
            progress.virtualDayOffset = 0

        case .nearVictory:
            progress.goalMode = .strictAbstinence
            progress.weeklySessionLimit = 2
            progress.activeMonsterLevel = 2
            progress.currentMonsterHP = 90
            progress.currentStreak = 3
            progress.totalCleanCheckIns = 8
            progress.totalDamageDealt = 910
            progress.totalMonstersDefeated = 1
            progress.defeatedMonsterLevels = [1]
            progress.honestShieldCount = 1
            progress.insightXP = 25
            progress.hasCompletedCampaign = false
            progress.virtualDayOffset = 0

            seeded = [
                CheckInRecord(simulatedDate: day(-5), outcome: .soberAttack, hpDelta: -100, monsterLevel: 1),
                CheckInRecord(simulatedDate: day(-4), outcome: .honestShieldRelapse, hpDelta: 45, monsterLevel: 2, drinkUnits: 1, triggers: [.socialGathering]),
                CheckInRecord(simulatedDate: day(-3), outcome: .soberAttack, hpDelta: -100, monsterLevel: 2),
                CheckInRecord(simulatedDate: day(-2), outcome: .soberAttack, hpDelta: -110, monsterLevel: 2),
                CheckInRecord(simulatedDate: day(-1), outcome: .soberAttack, hpDelta: -120, monsterLevel: 2)
            ]

        case .shieldStandby:
            progress.goalMode = .moderationBudget
            progress.weeklySessionLimit = 2
            progress.activeMonsterLevel = 2
            progress.currentMonsterHP = 400
            progress.currentStreak = 3
            progress.totalCleanCheckIns = 6
            progress.totalDamageDealt = 630
            progress.totalMonstersDefeated = 1
            progress.defeatedMonsterLevels = [1]
            progress.honestShieldCount = 0
            progress.insightXP = 0
            progress.hasCompletedCampaign = false
            // 設定在週日模擬位置，使本週已用 2/2 次留在同一週供立即展示超標護盾
            let iso = mondayCalendar(basedOn: calendar)
            let weekday = iso.component(.weekday, from: today)
            // weekday 1 = Sunday; ensure offset puts simulated day >= Wednesday so -2/-1 stays in same week
            let safeOffset = weekday == 2 ? 3 : (weekday == 3 ? 2 : 0)
            progress.virtualDayOffset = safeOffset
            let simToday = day(safeOffset)
            func simDay(_ delta: Int) -> Date {
                calendar.date(byAdding: .day, value: delta, to: simToday) ?? simToday
            }
            seeded = [
                CheckInRecord(simulatedDate: simDay(-3), outcome: .soberAttack, hpDelta: -110, monsterLevel: 2),
                CheckInRecord(simulatedDate: simDay(-2), outcome: .withinBudgetDrink, hpDelta: 15, monsterLevel: 2, drinkUnits: 1, triggers: [.socialGathering]),
                CheckInRecord(simulatedDate: simDay(-1), outcome: .withinBudgetDrink, hpDelta: 30, monsterLevel: 2, drinkUnits: 2, triggers: [.celebration])
            ]

        case .richWeekHistory:
            progress.goalMode = .moderationBudget
            progress.weeklySessionLimit = 2
            progress.activeMonsterLevel = 3
            progress.currentMonsterHP = 850
            progress.currentStreak = 4
            progress.totalCleanCheckIns = 15
            progress.totalDamageDealt = 1850
            progress.totalMonstersDefeated = 2
            progress.defeatedMonsterLevels = [1, 2]
            progress.honestShieldCount = 3
            progress.insightXP = 75
            progress.hasCompletedCampaign = false
            progress.virtualDayOffset = 0

            seeded = [
                CheckInRecord(simulatedDate: day(-6), outcome: .soberAttack, hpDelta: -120, monsterLevel: 2),
                CheckInRecord(simulatedDate: day(-5), outcome: .honestShieldRelapse, hpDelta: 90, monsterLevel: 2, drinkUnits: 2, triggers: [.socialGathering, .peerPressure]),
                CheckInRecord(simulatedDate: day(-4), outcome: .soberAttack, hpDelta: -100, monsterLevel: 2),
                CheckInRecord(simulatedDate: day(-3), outcome: .withinBudgetDrink, hpDelta: 15, monsterLevel: 3, drinkUnits: 1, triggers: [.celebration]),
                CheckInRecord(simulatedDate: day(-2), outcome: .soberAttack, hpDelta: -120, monsterLevel: 3),
                CheckInRecord(simulatedDate: day(-1), outcome: .honestShieldRelapse, hpDelta: 45, monsterLevel: 3, drinkUnits: 1, triggers: [.workStress])
            ]
        }

        for record in seeded {
            context.insert(record)
        }
        try? context.save()
        syncSnapshot(progress: progress, records: seeded, now: now, calendar: calendar)
    }
}
