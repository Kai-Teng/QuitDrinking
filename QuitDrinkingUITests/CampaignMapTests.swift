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
        attachScreen("關卡地圖", app: app)

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
    func testDrinkingCheckInAppearsInJournal() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestInMemoryStore"]
        app.launch()

        let drink = app.buttons["battle.logDrink"]
        XCTAssertTrue(drink.waitForExistence(timeout: 10))
        attachScreen("今日戰場", app: app)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "今日沒喝")).firstMatch.tap()
        drink.tap()
        let submit = app.buttons["drink.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled)
        let guide = app.buttons["一標準杯有多少？"]
        guide.tap()
        let beerServing = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "250 mL", "250 mL")
        ).firstMatch
        XCTAssertTrue(beerServing.waitForExistence(timeout: 5))
        guide.tap()
        app.buttons["聚餐應酬"].tap()
        XCTAssertTrue(submit.isEnabled)
        attachScreen("喝酒紀錄", app: app)
        submit.tap()
        app.tabBars.buttons["戰績"].tap()
        XCTAssertTrue(app.staticTexts["1 天沒喝酒，1 天有喝酒"].waitForExistence(timeout: 5))
        attachScreen("飲酒手帳", app: app)
    }

    @MainActor
    private func attachScreen(_ name: String, app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
