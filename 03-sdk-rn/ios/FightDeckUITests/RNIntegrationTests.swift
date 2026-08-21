import XCTest

final class RNIntegrationTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(skipPrewarm: Bool = false) {
        app.launchArguments = skipPrewarm ? ["-SkipRNPrewarm"] : []
        app.launch()
    }

    private func goToSlipTab() {
        app.tabBars.buttons["Slip"].tap()
    }

    /// Odds buttons only appear on the Upcoming tab. Pick one leg so the slip RN surface
    /// shows the deposit card with an Add funds action.
    private func addSelectionFromUpcoming() {
        app.tabBars.buttons["Upcoming"].tap()
        let event = app.staticTexts["UFC Freedom 250"]
        XCTAssertTrue(event.waitForExistence(timeout: 15))
        event.tap()
        let odds = app.buttons["1.20"].firstMatch
        XCTAssertTrue(odds.waitForExistence(timeout: 15))
        odds.tap()
    }

    private func launchToDeposit(skipPrewarm: Bool) -> Int {
        let start = Date()
        launch(skipPrewarm: skipPrewarm)
        addSelectionFromUpcoming()
        goToSlipTab()
        let addFunds = app.buttons["Add funds"]
        XCTAssertTrue(addFunds.waitForExistence(timeout: 30))
        addFunds.tap()
        let ready = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Balance'")
        ).firstMatch.waitForExistence(timeout: 30)
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        NSLog(
            "[FightDeckBenchmark] mode=%@ firstSurfaceMs=%d ready=%@",
            skipPrewarm ? "unprewarmed" : "prewarmed",
            elapsed,
            ready ? "true" : "false"
        )
        XCTAssertTrue(ready)
        return elapsed
    }

    func testUnprewarmedFirstDepositSurface() throws {
        _ = launchToDeposit(skipPrewarm: true)
    }

    func testPrewarmedFirstDepositSurface() throws {
        _ = launchToDeposit(skipPrewarm: false)
    }

    func testDepositScreenIsReactNative() throws {
        launch()
        addSelectionFromUpcoming()
        goToSlipTab()
        app.buttons["Add funds"].tap()

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Balance'")).firstMatch
                .waitForExistence(timeout: 30)
        )
    }

    func testBetslipScreenIsReactNative() throws {
        launch()
        goToSlipTab()

        XCTAssertTrue(
            app.staticTexts["No selections yet"].waitForExistence(timeout: 30)
                || app.buttons["Browse Events"].waitForExistence(timeout: 1)
        )
    }
}
