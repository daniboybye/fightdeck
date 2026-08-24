//
// ScreenshotTour.swift
// FightDeckUITests
//
// Created by FightDeck on 23.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import XCTest

final class ScreenshotTour: XCTestCase {
    func testTour() {
        let app = XCUIApplication()
        app.launchEnvironment["FIGHTDECK_DATASET_ROOT"] = datasetRoot
        app.launch()
        sleep(4)
        shot("01-upcoming")

        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Freedom")).firstMatch.tap()
        sleep(2)
        shot("02-event")

        let bout = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Topuria")).firstMatch
        if bout.waitForExistence(timeout: 3) {
            bout.tap()
            sleep(2)
            shot("03-bout")
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "1.2")).firstMatch.tap()
            sleep(1)
            shot("04-bout-selected")
            app.swipeUp()
            sleep(1)
            shot("05-tape")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "UFC 328")).firstMatch.tap()
        sleep(2)
        let longCountry = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Cortes")).firstMatch
        if longCountry.waitForExistence(timeout: 5) {
            longCountry.tap()
            sleep(2)
            app.swipeUp()
            sleep(1)
            shot("05b-tape-long-country")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // The tab bar minimises on scroll down; nudge it back before reaching for a tab.
        app.swipeDown()
        sleep(1)
        app.tabBars.buttons["Slip"].tap()
        sleep(3)
        shot("06-slip")

        let amount = visibleTextField(in: app)
        if amount.waitForExistence(timeout: 3) {
            focus(amount, in: app)
            shot("07-slip-keyboard")
            let done = app.buttons["Done"].firstMatch
            if done.waitForExistence(timeout: 2) {
                done.tap()
                sleep(1)
            }
        }

        app.buttons["Add funds"].firstMatch.tap()
        sleep(2)
        shot("08-deposit")
        let depositAmount = visibleTextField(in: app)
        if depositAmount.waitForExistence(timeout: 3) {
            focus(depositAmount, in: app)
            depositAmount.typeText("50")
            sleep(2)
            shot("09-deposit-keyboard")
            let done = app.buttons["Done"].firstMatch
            if done.waitForExistence(timeout: 2) {
                done.tap()
                sleep(1)
            }
            app.buttons["Confirm deposit"].firstMatch.tap()
            sleep(2)
            shot("10-deposit-success")
            app.buttons["Done"].firstMatch.tap()
            sleep(2)
        }

        shot("11-slip-after-deposit")
        app.buttons["Place bet"].firstMatch.tap()
        sleep(2)
        shot("12-bet-placed")

        app.tabBars.buttons["Past"].tap()
        sleep(3)
        shot("13-past")
        for _ in 0..<10 {
            app.swipeUp()
        }
        sleep(2)
        shot("14-past-scrolled")
    }

    private var datasetRoot: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dataset")
            .path
    }

    /// Tabs that have already been visited keep their fields in the hierarchy, so `firstMatch`
    /// can hand back a search field from another screen.
    private func visibleTextField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.allElementsBoundByIndex.first { $0.isHittable } ?? app.textFields.firstMatch
    }

    /// A React Native `TextInput` does not always take focus from a hit on the element's centre,
    /// which for a labelled row lands on the label rather than the field.
    private func focus(_ field: XCUIElement, in app: XCUIApplication) {
        field.tap()
        if app.keyboards.element.waitForExistence(timeout: 3) {
            sleep(1)
            return
        }
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        _ = app.keyboards.element.waitForExistence(timeout: 3)
        sleep(1)
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
