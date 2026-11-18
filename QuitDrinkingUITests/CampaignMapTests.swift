import XCTest

final class CampaignMapTests: XCTestCase {
    @MainActor
    func testMapReflectsBattleProgressAndGuardsLockedStages() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestInMemoryStore"]
        app.launch()

        let battleTab = app.tabBars.buttons["戰場"]
        let mapTab = app.tabBars.buttons["關卡"]
        XCTAssertTrue(battleTab.waitForExistence(timeout: 10))
        XCTAssertTrue(battleTab.isSelected)
        XCTAssertLessThan(battleTab.frame.midX, mapTab.frame.midX)
        XCTAssertLessThan(mapTab.frame.midX, app.tabBars.buttons["戰績"].frame.midX)

        app.buttons["開啟 MAIC Demo 控制台"].tap()
        app.buttons.containing(.staticText, identifier: "精彩時刻：Lv.2 殘血待斬").firstMatch.tap()
        mapTab.tap()
        let current = app.buttons["campaign.stop.2"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        XCTAssertTrue((current.value as? String)?.contains("90 / 700") == true)
        XCTAssertEqual(app.buttons["campaign.stop.1"].value as? String, "已擊敗")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "關卡地圖"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["campaign.stop.3"].tap()
        XCTAssertTrue(app.staticTexts["擊敗 Lv.2 怪獸後解鎖"].exists)
        XCTAssertFalse(app.buttons["再次挑戰"].exists)
        app.buttons["關閉"].tap()
        current.tap()
        app.buttons["前往戰場"].tap()
        XCTAssertTrue(battleTab.isSelected)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "今日沒喝")).firstMatch.tap()
        let next = app.buttons["迎戰 Lv.3 宿醉巨龍"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        mapTab.tap()
        XCTAssertEqual(current.value as? String, "已擊敗")
        XCTAssertTrue((app.buttons["campaign.stop.3"].value as? String)?.contains("交戰中") == true)
    }

    @MainActor
    func testMapAtAccessibilityTextSize() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestInMemoryStore", "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["關卡"].tap()
        let first = app.buttons["campaign.stop.1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(app.buttons["前往戰場"].exists)
    }
}
