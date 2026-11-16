import XCTest
@testable import QuitDrinking

final class SharedSnapshotStoreTests: XCTestCase {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "test.dawnquest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testSaveAndLoadRoundTrip() {
        let suite = makeIsolatedDefaults()
        let fallback = makeIsolatedDefaults()
        let expected = BattleWidgetSnapshot(
            monsterLevel: 2,
            monsterName: "啤酒肚哥布林",
            monsterSymbolName: "mug.fill",
            currentHP: 420,
            maxHP: 700,
            currentStreak: 4,
            goalModeRaw: "moderationBudget",
            weeklyUsedCount: 1,
            weeklySessionLimit: 2,
            totalSavedNTD: 1250,
            updatedAt: Date(timeIntervalSince1970: 1_763_200_000)
        )

        SharedSnapshotStore.save(expected, suiteDefaults: suite, fallbackDefaults: fallback)
        let loaded = SharedSnapshotStore.load(suiteDefaults: suite, fallbackDefaults: fallback)

        XCTAssertEqual(loaded, expected)
    }

    func testLoadFallsBackToStandardDefaultsWhenSuiteNil() {
        let fallback = makeIsolatedDefaults()
        let expected = BattleWidgetSnapshot(
            monsterLevel: 3,
            monsterName: "宿醉巨龍",
            monsterSymbolName: "flame.fill",
            currentHP: 950,
            maxHP: 1400,
            currentStreak: 9,
            goalModeRaw: "strictAbstinence",
            weeklyUsedCount: 0,
            weeklySessionLimit: 2,
            totalSavedNTD: 3000,
            updatedAt: Date(timeIntervalSince1970: 1_763_200_500)
        )

        SharedSnapshotStore.save(expected, suiteDefaults: nil, fallbackDefaults: fallback)
        let loaded = SharedSnapshotStore.load(suiteDefaults: nil, fallbackDefaults: fallback)

        XCTAssertEqual(loaded, expected)
    }

    func testLoadEmptyDefaultsReturnsPlaceholder() {
        let suite = makeIsolatedDefaults()
        let fallback = makeIsolatedDefaults()

        let loaded = SharedSnapshotStore.load(suiteDefaults: suite, fallbackDefaults: fallback)

        XCTAssertEqual(loaded, .placeholder)
    }
}
