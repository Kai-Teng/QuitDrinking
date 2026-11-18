import Foundation
import SwiftData
import WidgetKit

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

enum CombatCheckIn {
    case soberAttack
    case drink(units: Int, triggers: [RelapseTriggerTag], note: String)
}

/// 打卡動作回傳結果，供 View 觸發對應動效與覆蓋層。
enum CombatActionStatus: Equatable, Sendable {
    case applied(CombatActionSummary)
    case requiresTrigger
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
    ) -> (day: Date, daysAdvanced: Int)? {
        let today = effectiveToday(for: progress, now: now, calendar: calendar)
        guard hasRecord(on: today, records: records, calendar: calendar) else { return (today, 0) }
        guard progress.demoRapidMode else { return nil }

        let recordedDays = Set(records.map { calendar.startOfDay(for: $0.simulatedDate) })
        var day = today
        var daysAdvanced = 0
        repeat {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { return nil }
            day = next
            daysAdvanced += 1
        } while recordedDays.contains(day)
        return (day, daysAdvanced)
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
        return records.count { record in
            record.simulatedDate >= weekInterval.start && record.simulatedDate < weekInterval.end
                && (record.outcome == .withinBudgetDrink || record.outcome == .honestShieldRelapse)
        }
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
        guard progress.goalMode == .moderationBudget else { return true }
        let weeklyUsed = nextCheckInWeeklyDrinksUsed(progress: progress, records: records, now: now, calendar: calendar)
        return requiresHonestShield(progress: progress, weeklyUsed: weeklyUsed)
    }

    static func requiresHonestShield(progress: PlayerProgress, weeklyUsed: Int) -> Bool {
        progress.goalMode == .strictAbstinence || weeklyUsed >= progress.weeklySessionLimit
    }

    static func nextCheckInWeeklyDrinksUsed(
        progress: PlayerProgress,
        records: [CheckInRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let day = resolveTargetDay(for: progress, records: records, now: now, calendar: calendar)?.day
            ?? effectiveToday(for: progress, now: now, calendar: calendar)
        return weeklyDrinksUsed(on: day, records: records, calendar: calendar)
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

    static func appliedHealAmount(units: Int, monsterMaxHP: Int, currentHP: Int, triggersShield: Bool) -> Int {
        let heal = triggersShield
            ? honestShieldHealAmount(units: units, monsterMaxHP: monsterMaxHP)
            : withinBudgetHealAmount(units: units, monsterMaxHP: monsterMaxHP)
        return min(heal, max(0, monsterMaxHP - currentHP))
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

    /// 從目前的 context 讀取本週起的紀錄，連點兩次也會看到前次提交。
    @MainActor
    static func checkIn(
        _ action: CombatCheckIn, progress: PlayerProgress, context: ModelContext,
        now: Date = .now, calendar: Calendar = .current
    ) throws -> CombatActionStatus {
        let today = effectiveToday(for: progress, now: now, calendar: calendar)
        let start = mondayCalendar(basedOn: calendar).dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let descriptor = FetchDescriptor<CheckInRecord>(predicate: #Predicate { $0.simulatedDate >= start })
        var records = try context.fetch(descriptor)
        func insert(_ record: CheckInRecord) {
            context.insert(record)
            records.append(record)
        }

        let result: CombatActionStatus
        switch action {
        case .soberAttack:
            result = logSoberAttack(progress: progress, records: records, insertRecord: insert, now: now, calendar: calendar)
        case let .drink(units, triggers, note):
            result = logDrink(progress: progress, records: records, units: units, triggers: triggers,
                              note: note, insertRecord: insert, now: now, calendar: calendar)
        }
        if case .applied = result {
            try saveAndSync(progress: progress, records: records, context: context, now: now, calendar: calendar)
        }
        return result
    }

    @MainActor
    static func saveAndSync(
        progress: PlayerProgress, records: [CheckInRecord], context: ModelContext,
        now: Date = .now, calendar: Calendar = .current
    ) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        syncSnapshot(progress: progress, records: records, now: now, calendar: calendar)
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

        progress.virtualDayOffset += resolved.daysAdvanced
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

        return .applied(
            CombatActionSummary(
                outcome: .soberAttack,
                hpDelta: -damage,
                defeatedMonster: defeated,
                promotedToMonster: promotedTo,
                completedCampaign: completedCampaignNow,
                didAdvanceVirtualDay: resolved.daysAdvanced > 0,
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
        let triggersShield = requiresHonestShield(progress: progress, weeklyUsed: usedBefore)

        guard !triggersShield || !triggers.isEmpty else { return .requiresTrigger }
        let healAmount = appliedHealAmount(units: units, monsterMaxHP: currentSpec.maxHP,
                                           currentHP: progress.currentMonsterHP, triggersShield: triggersShield)
        let outcome: CheckInOutcomeType
        progress.virtualDayOffset += resolved.daysAdvanced

        if triggersShield {
            outcome = .honestShieldRelapse
            progress.currentStreak = 0
            progress.honestShieldCount += 1
            progress.insightXP += insightXPPerShield
        } else {
            outcome = .withinBudgetDrink
        }

        progress.currentMonsterHP = min(currentSpec.maxHP, progress.currentMonsterHP + healAmount)

        let record = CheckInRecord(
            simulatedDate: resolved.day,
            createdAt: now,
            outcome: outcome,
            hpDelta: healAmount,
            monsterLevel: currentSpec.level,
            drinkUnits: max(1, units),
            triggers: triggers,
            note: note
        )
        insertRecord(record)

        return .applied(
            CombatActionSummary(
                outcome: outcome,
                hpDelta: healAmount,
                defeatedMonster: nil,
                promotedToMonster: nil,
                completedCampaign: false,
                didAdvanceVirtualDay: resolved.daysAdvanced > 0,
                recordDate: resolved.day
            )
        )
    }

    @MainActor
    @discardableResult
    static func rematchMonster(level: Int, progress: PlayerProgress) -> Bool {
        guard progress.hasCompletedCampaign,
              let targetSpec = MonsterCatalog.all.first(where: { $0.level == level }) else { return false }
        progress.activeMonsterLevel = targetSpec.level
        progress.currentMonsterHP = targetSpec.maxHP
        return true
    }

    // MARK: - Analytics Helpers

    static func recentSevenDayBuckets(
        progress: PlayerProgress,
        records: [CheckInRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyChartBucket] {
        let today = effectiveToday(for: progress, now: now, calendar: calendar)
        guard let firstDay = calendar.date(byAdding: .day, value: -6, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        var lastRecordByDay: [Date: CheckInRecord] = [:]
        for record in records where (firstDay..<tomorrow).contains(record.simulatedDate) {
            let day = calendar.startOfDay(for: record.simulatedDate)
            if let previous = lastRecordByDay[day] {
                if previous.createdAt > record.createdAt { continue }
                if previous.createdAt == record.createdAt, previous.id.uuidString > record.id.uuidString { continue }
            }
            lastRecordByDay[day] = record
        }

        return (-6...0).compactMap { delta in
            guard let day = calendar.date(byAdding: .day, value: delta, to: today) else { return nil }
            let label = delta == 0 ? "今日" : "\(calendar.component(.month, from: day))/\(calendar.component(.day, from: day))"
            let record = lastRecordByDay[day]
            return DailyChartBucket(date: day, dayLabel: label, outcome: record?.outcome, magnitude: Int(clamping: (record?.hpDelta ?? 0).magnitude))
        }
    }

    static func triggerBreakdown(from records: [CheckInRecord]) -> [TriggerStatItem] {
        var counts: [RelapseTriggerTag: Int] = [:]
        var total = 0
        for record in records where record.outcome == .honestShieldRelapse {
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
        guard progress.modelContext?.container.configurations.allSatisfy(\.isStoredInMemoryOnly) != true else { return }
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
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor
    static func applyDemoPreset(
        _ preset: MAICDemoPreset,
        progress: PlayerProgress,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        for record in try context.fetch(FetchDescriptor<CheckInRecord>()) {
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
            // 保證前兩天的小酌都落在目前的週額度內。
            let iso = mondayCalendar(basedOn: calendar)
            let weekday = iso.component(.weekday, from: today)
            let safeOffset = weekday == 2 ? 3 : (weekday == 3 ? 2 : 0)
            progress.virtualDayOffset = safeOffset
            let simToday = day(safeOffset)
            func simDay(_ delta: Int) -> Date {
                calendar.date(byAdding: .day, value: delta, to: simToday) ?? simToday
            }
            seeded = [
                CheckInRecord(simulatedDate: simDay(-5), outcome: .soberAttack, hpDelta: -100, monsterLevel: 1),
                CheckInRecord(simulatedDate: simDay(-4), outcome: .soberAttack, hpDelta: -110, monsterLevel: 2),
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
                CheckInRecord(simulatedDate: day(-6), outcome: .honestShieldRelapse, hpDelta: 90, monsterLevel: 2, drinkUnits: 2, triggers: [.socialGathering, .peerPressure]),
                CheckInRecord(simulatedDate: day(-5), outcome: .withinBudgetDrink, hpDelta: 15, monsterLevel: 2, drinkUnits: 1),
                CheckInRecord(simulatedDate: day(-4), outcome: .honestShieldRelapse, hpDelta: 45, monsterLevel: 2, drinkUnits: 1, triggers: [.workStress]),
                CheckInRecord(simulatedDate: day(-3), outcome: .soberAttack, hpDelta: -100, monsterLevel: 2),
                CheckInRecord(simulatedDate: day(-2), outcome: .soberAttack, hpDelta: -110, monsterLevel: 3),
                CheckInRecord(simulatedDate: day(-1), outcome: .soberAttack, hpDelta: -120, monsterLevel: 3),
                CheckInRecord(simulatedDate: day(0), outcome: .soberAttack, hpDelta: -130, monsterLevel: 3)
            ]
        }

        for record in seeded {
            context.insert(record)
        }
        try saveAndSync(progress: progress, records: seeded, context: context, now: now, calendar: calendar)
    }
}
