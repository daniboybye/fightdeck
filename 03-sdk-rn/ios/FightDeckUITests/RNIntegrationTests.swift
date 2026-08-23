import XCTest

final class RNIntegrationTests: XCTestCase {
    private var app: XCUIApplication!

    private enum TestId {
        static let betslipAddFunds = "betslip-add-funds"
        static let betslipEmpty = "betslip-empty"
        static let depositReady = "deposit-ready"
        static let depositBalance = "deposit-balance"
    }

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

    /// Matches React Native `testID` values exposed as accessibility identifiers.
    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
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

    private func waitForBetslipAddFunds(timeout: TimeInterval = 30) -> Bool {
        element(identifier: TestId.betslipAddFunds).waitForExistence(timeout: timeout)
    }

    private func waitForDepositReady(timeout: TimeInterval = 30) -> Bool {
        element(identifier: TestId.depositReady).waitForExistence(timeout: timeout)
            || element(identifier: TestId.depositBalance).waitForExistence(timeout: timeout)
    }

    private func launchToDeposit(skipPrewarm: Bool) -> Int {
        let start = Date()
        launch(skipPrewarm: skipPrewarm)
        addSelectionFromUpcoming()
        goToSlipTab()
        XCTAssertTrue(waitForBetslipAddFunds())
        element(identifier: TestId.betslipAddFunds).tap()
        let ready = waitForDepositReady()
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
        XCTAssertTrue(waitForBetslipAddFunds())
        element(identifier: TestId.betslipAddFunds).tap()
        XCTAssertTrue(waitForDepositReady())
    }

    func testBetslipScreenIsReactNative() throws {
        launch()
        goToSlipTab()

        XCTAssertTrue(
            element(identifier: TestId.betslipEmpty).waitForExistence(timeout: 30)
                || app.staticTexts["No selections yet"].waitForExistence(timeout: 1)
                || app.buttons["Browse Events"].waitForExistence(timeout: 1)
        )
    }
}
