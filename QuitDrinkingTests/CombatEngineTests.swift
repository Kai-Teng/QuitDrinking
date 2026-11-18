import XCTest
import SwiftData
@testable import QuitDrinking

@MainActor
final class CombatEngineTests: XCTestCase {
    private var fixedCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 20)
        return fixedCalendar.date(from: components)!
    }

    func testSoberAttackDamageAndComboCap() {
        let progress = PlayerProgress()
        XCTAssertEqual(CombatEngine.previewAttackDamage(for: progress), 100)

        progress.currentStreak = 3
        XCTAssertEqual(CombatEngine.previewAttackDamage(for: progress), 130)

        progress.currentStreak = 12
        XCTAssertEqual(CombatEngine.previewAttackDamage(for: progress), 150)
    }

    func testDefeatMonsterPromotesToFullHPWithoutCarryover() {
        let progress = PlayerProgress(activeMonsterLevel: 1, currentMonsterHP: 90, currentStreak: 2)
        var records: [CheckInRecord] = []
        let now = makeDate(year: 2026, month: 11, day: 16)

        let status = CombatEngine.logSoberAttack(
            progress: progress,
            records: records,
            insertRecord: { records.append($0) },
            now: now,
            calendar: fixedCalendar
        )

        guard case .applied(let summary) = status else {
            return XCTFail("Expected attack to succeed")
        }

        XCTAssertEqual(summary.hpDelta, -120)
        XCTAssertEqual(summary.defeatedMonster?.level, 1)
        XCTAssertEqual(summary.promotedToMonster?.level, 2)
        XCTAssertFalse(summary.completedCampaign)
        XCTAssertEqual(progress.activeMonsterLevel, 2)
        XCTAssertEqual(progress.currentMonsterHP, 700, "Next monster must enter at full HP without overflow damage")
        XCTAssertEqual(progress.totalMonstersDefeated, 1)
        XCTAssertTrue(progress.defeatedMonsterLevels.contains(1))
    }

    func testStrictAbstinenceDrinkTriggersHonestShieldAndCapsHeal() {
        let progress = PlayerProgress(
            goalMode: .strictAbstinence,
            activeMonsterLevel: 2,
            currentMonsterHP: 650,
            currentStreak: 4,
            totalCleanCheckIns: 6,
            totalMonstersDefeated: 1,
            defeatedMonsterLevels: [1]
        )
        var records: [CheckInRecord] = []
        let now = makeDate(year: 2026, month: 11, day: 16)

        let status = CombatEngine.logDrink(
            progress: progress,
            records: records,
            units: 10,
            triggers: [.workStress, .socialGathering],
            note: "加班聚餐",
            insertRecord: { records.append($0) },
            now: now,
            calendar: fixedCalendar
        )

        guard case .applied(let summary) = status else {
            return XCTFail("Expected drink log to apply")
        }

        XCTAssertEqual(summary.outcome, .honestShieldRelapse)
        XCTAssertEqual(CombatEngine.honestShieldHealAmount(units: 10, monsterMaxHP: 700), 140)
        XCTAssertEqual(summary.hpDelta, 50, "Report only the HP actually restored")
        XCTAssertEqual(records.first?.hpDelta, 50)
        XCTAssertEqual(progress.currentMonsterHP, 700, "HP cannot exceed current monster maxHP or regress to Lv.1")
        XCTAssertEqual(progress.activeMonsterLevel, 2)
        XCTAssertEqual(progress.currentStreak, 0)
        XCTAssertEqual(progress.totalCleanCheckIns, 6, "Lifetime clean count must not be wiped")
        XCTAssertEqual(progress.honestShieldCount, 1)
        XCTAssertEqual(progress.insightXP, 25)
    }

    func testModerationBudgetWithinLimitPreservesStreakAndResetsNextWeek() {
        // 2026-11-16 is a Monday
        let monday = makeDate(year: 2026, month: 11, day: 16)
        let progress = PlayerProgress(
            goalMode: .moderationBudget,
            weeklySessionLimit: 2,
            activeMonsterLevel: 2,
            currentMonsterHP: 400,
            currentStreak: 3,
            demoRapidMode: true
        )
        var records: [CheckInRecord] = []

        // First drink on Monday: within budget (0 < 2)
        let first = CombatEngine.logDrink(
            progress: progress,
            records: records,
            units: 2,
            triggers: [.socialGathering],
            note: "",
            insertRecord: { records.append($0) },
            now: monday,
            calendar: fixedCalendar
        )
        guard case .applied(let s1) = first else { return XCTFail("Expected first drink") }
        XCTAssertEqual(s1.outcome, .withinBudgetDrink)
        XCTAssertEqual(s1.hpDelta, 30)
        XCTAssertEqual(progress.currentStreak, 3, "Within-budget drink preserves daily combo streak")

        // Second drink advances virtual day to Tuesday (1 < 2 -> still within budget)
        let second = CombatEngine.logDrink(
            progress: progress,
            records: records,
            units: 1,
            triggers: [.celebration],
            note: "",
            insertRecord: { records.append($0) },
            now: monday,
            calendar: fixedCalendar
        )
        guard case .applied(let s2) = second else { return XCTFail("Expected second drink") }
        XCTAssertEqual(s2.outcome, .withinBudgetDrink)
        XCTAssertTrue(s2.didAdvanceVirtualDay)
        XCTAssertEqual(progress.currentStreak, 3)

        // Third drink advances to Wednesday (2 >= 2 -> triggers Honest Shield)
        let third = CombatEngine.logDrink(
            progress: progress,
            records: records,
            units: 1,
            triggers: [.peerPressure],
            note: "",
            insertRecord: { records.append($0) },
            now: monday,
            calendar: fixedCalendar
        )
        guard case .applied(let s3) = third else { return XCTFail("Expected third drink") }
        XCTAssertEqual(s3.outcome, .honestShieldRelapse)
        XCTAssertEqual(progress.honestShieldCount, 1)
        XCTAssertEqual(progress.currentStreak, 0)

        // Jump to next Monday (virtualDayOffset = 7): weekly count resets to 0
        progress.virtualDayOffset = 7
        XCTAssertEqual(
            CombatEngine.currentWeeklyDrinksUsed(progress: progress, records: records, now: monday, calendar: fixedCalendar),
            0
        )
        XCTAssertFalse(
            CombatEngine.willTriggerHonestShieldOnDrink(progress: progress, records: records, now: monday, calendar: fixedCalendar)
        )
    }

    func testMidWeekSwitchFromStrictToModerationCountsExistingWeekDrinks() {
        let monday = makeDate(year: 2026, month: 11, day: 16)
        let progress = PlayerProgress(goalMode: .strictAbstinence, weeklySessionLimit: 2)
        var records: [CheckInRecord] = []

        _ = CombatEngine.logDrink(
            progress: progress,
            records: records,
            units: 1,
            triggers: [.workStress],
            note: "",
            insertRecord: { records.append($0) },
            now: monday,
            calendar: fixedCalendar
        )

        progress.goalMode = .moderationBudget
        XCTAssertEqual(
            CombatEngine.currentWeeklyDrinksUsed(progress: progress, records: records, now: monday, calendar: fixedCalendar),
            1
        )
    }

    func testCampaignCompletionAndRematchPreservesLifetimeStats() {
        let progress = PlayerProgress(
            activeMonsterLevel: 4,
            currentMonsterHP: 80,
            currentStreak: 5,
            totalCleanCheckIns: 30,
            totalMonstersDefeated: 3,
            defeatedMonsterLevels: [1, 2, 3],
            honestShieldCount: 2,
            insightXP: 50
        )
        var records: [CheckInRecord] = []
        let now = makeDate(year: 2026, month: 11, day: 16)

        let status = CombatEngine.logSoberAttack(
            progress: progress,
            records: records,
            insertRecord: { records.append($0) },
            now: now,
            calendar: fixedCalendar
        )
        guard case .applied(let summary) = status else { return XCTFail("Expected final blow") }
        XCTAssertTrue(summary.completedCampaign)
        XCTAssertTrue(progress.hasCompletedCampaign)
        XCTAssertEqual(progress.currentMonsterHP, 0)
        XCTAssertEqual(progress.totalMonstersDefeated, 4)

        // Attacking while in victory standby prompts rematch instead of mutating
        let blocked = CombatEngine.logSoberAttack(
            progress: progress,
            records: records,
            insertRecord: { records.append($0) },
            now: now,
            calendar: fixedCalendar
        )
        XCTAssertEqual(blocked, .campaignStandbyRequiresRematch)

        // Rematch Lv.1 preserves lifetime stats
        XCTAssertTrue(CombatEngine.rematchMonster(level: 1, progress: progress))
        XCTAssertEqual(progress.activeMonsterLevel, 1)
        XCTAssertEqual(progress.currentMonsterHP, 300)
        XCTAssertEqual(progress.totalCleanCheckIns, 31)
        XCTAssertEqual(progress.totalMonstersDefeated, 4)
        XCTAssertEqual(progress.honestShieldCount, 2)
        XCTAssertEqual(progress.insightXP, 50)
        XCTAssertEqual(progress.currentStreak, 6)
    }

    func testRematchRejectsLockedOrUnknownLevels() {
        let progress = PlayerProgress(activeMonsterLevel: 3, currentMonsterHP: 800)
        XCTAssertFalse(CombatEngine.rematchMonster(level: 1, progress: progress))
        progress.hasCompletedCampaign = true
        XCTAssertFalse(CombatEngine.rematchMonster(level: 99, progress: progress))
        XCTAssertEqual(progress.activeMonsterLevel, 3)
        XCTAssertEqual(progress.currentMonsterHP, 800)
    }

    func testRejectedShieldDoesNotAdvanceDayOrInventTrigger() {
        let today = makeDate(year: 2026, month: 11, day: 16)
        let progress = PlayerProgress(currentMonsterHP: 180, currentStreak: 1)
        let records = [CheckInRecord(simulatedDate: today, outcome: .soberAttack, hpDelta: -100, monsterLevel: 1)]
        let result = CombatEngine.logDrink(
            progress: progress, records: records, units: 1, triggers: [], note: "",
            insertRecord: { _ in XCTFail("Invalid forms must not create a record") }, now: today, calendar: fixedCalendar
        )
        XCTAssertEqual(result, .requiresTrigger)
        XCTAssertEqual(progress.virtualDayOffset, 0)
        XCTAssertEqual(progress.currentStreak, 1)
        XCTAssertEqual(progress.honestShieldCount, 0)
        XCTAssertEqual(progress.currentMonsterHP, 180)
    }

    func testPreviewAndWriteAgreeAcrossSundayToMonday() {
        let sunday = makeDate(year: 2026, month: 11, day: 22)
        let monday = fixedCalendar.startOfDay(for: makeDate(year: 2026, month: 11, day: 23))
        let progress = PlayerProgress(goalMode: .moderationBudget, weeklySessionLimit: 1)
        var records = [CheckInRecord(simulatedDate: sunday, outcome: .withinBudgetDrink, hpDelta: 0, monsterLevel: 1)]
        XCTAssertFalse(CombatEngine.willTriggerHonestShieldOnDrink(progress: progress, records: records, now: sunday, calendar: fixedCalendar))
        let result = CombatEngine.logDrink(progress: progress, records: records, units: 1, triggers: [], note: "",
                                           insertRecord: { records.append($0) }, now: sunday, calendar: fixedCalendar)
        guard case .applied(let summary) = result else { return XCTFail("Expected Monday check-in") }
        XCTAssertEqual(summary.recordDate, monday)
        XCTAssertEqual(summary.outcome, .withinBudgetDrink)
        XCTAssertEqual(summary.hpDelta, 0)
        XCTAssertEqual(CombatEngine.weeklyDrinksUsed(on: sunday, records: records, calendar: fixedCalendar), 1)
    }

    func testPersistedCheckInRejectsRepeatedTapBeforeViewRefresh() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PlayerProgress.self, CheckInRecord.self, configurations: config)
        let context = container.mainContext
        let progress = PlayerProgress(demoRapidMode: false)
        context.insert(progress)
        let now = makeDate(year: 2026, month: 11, day: 16)
        _ = try CombatEngine.checkIn(.soberAttack, progress: progress, context: context, now: now, calendar: fixedCalendar)
        let retry = try CombatEngine.checkIn(.soberAttack, progress: progress, context: context, now: now, calendar: fixedCalendar)
        XCTAssertEqual(retry, .alreadyCheckedInToday)
        let reader = ModelContext(container)
        XCTAssertEqual(try reader.fetchCount(FetchDescriptor<CheckInRecord>()), 1)
        XCTAssertEqual(try reader.fetch(FetchDescriptor<PlayerProgress>()).first?.currentMonsterHP, 200)
    }

    func testDemoRapidModeVsStrictDailyLock() {
        let now = makeDate(year: 2026, month: 11, day: 16)
        let progress = PlayerProgress(demoRapidMode: true)
        var records: [CheckInRecord] = []

        // First tap stays on offset 0
        let r1 = CombatEngine.logSoberAttack(
            progress: progress,
            records: records,
            insertRecord: { records.append($0) },
            now: now,
            calendar: fixedCalendar
        )
        guard case .applied(let s1) = r1 else { return XCTFail() }
        XCTAssertFalse(s1.didAdvanceVirtualDay)
        XCTAssertEqual(progress.virtualDayOffset, 0)

        // Second tap in rapid mode advances virtual day to 1
        let r2 = CombatEngine.logSoberAttack(
            progress: progress,
            records: records,
            insertRecord: { records.append($0) },
            now: now,
            calendar: fixedCalendar
        )
        guard case .applied(let s2) = r2 else { return XCTFail() }
        XCTAssertTrue(s2.didAdvanceVirtualDay)
        XCTAssertEqual(progress.virtualDayOffset, 1)

        // Turning rapid mode OFF locks simulated today
        progress.demoRapidMode = false
        let r3 = CombatEngine.logSoberAttack(
            progress: progress,
            records: records,
            insertRecord: { records.append($0) },
            now: now,
            calendar: fixedCalendar
        )
        XCTAssertEqual(r3, .alreadyCheckedInToday)
        XCTAssertEqual(progress.virtualDayOffset, 1)
    }

    func testShieldStandbyDemoPresetSeedsSameWeekBudgetFull() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PlayerProgress.self, CheckInRecord.self, configurations: config)
        let context = container.mainContext
        let progress = PlayerProgress()
        context.insert(progress)

        let monday = makeDate(year: 2026, month: 11, day: 16)
        try CombatEngine.applyDemoPreset(.shieldStandby, progress: progress, context: context, now: monday, calendar: fixedCalendar)

        let records = try context.fetch(FetchDescriptor<CheckInRecord>())
        XCTAssertEqual(progress.goalMode, .moderationBudget)
        XCTAssertEqual(progress.activeMonsterLevel, 2)
        XCTAssertEqual(progress.currentMonsterHP, 400)
        XCTAssertEqual(CombatEngine.currentWeeklyDrinksUsed(progress: progress, records: records, now: monday, calendar: fixedCalendar), 2)
        XCTAssertTrue(CombatEngine.willTriggerHonestShieldOnDrink(progress: progress, records: records, now: monday, calendar: fixedCalendar))
    }
}

extension CombatEngineTests {
    func testSevenDayChartUsesSimulatedLocalDatesAndLatestSameDayRecord() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 14 * 3600))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 12)))
        let progress = PlayerProgress(virtualDayOffset: 2)
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 26)))
        let tomorrow = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 3)))
        let older = CheckInRecord(simulatedDate: firstDay, createdAt: now, outcome: .soberAttack, hpDelta: -100, monsterLevel: 1)
        let latest = CheckInRecord(simulatedDate: firstDay, createdAt: now.addingTimeInterval(1), outcome: .withinBudgetDrink, hpDelta: 15, monsterLevel: 1)
        let future = CheckInRecord(simulatedDate: tomorrow, outcome: .honestShieldRelapse, hpDelta: 45, monsterLevel: 1)

        let buckets = CombatEngine.recentSevenDayBuckets(progress: progress, records: [future, latest, older], now: now, calendar: calendar)
        XCTAssertEqual(buckets.map(\.dayLabel), ["11/26", "11/27", "11/28", "11/29", "11/30", "12/1", "今日"])
        XCTAssertEqual(buckets.compactMap(\.outcome), [.withinBudgetDrink])
        XCTAssertEqual(buckets.map(\.magnitude), [15, 0, 0, 0, 0, 0, 0])
    }
}
