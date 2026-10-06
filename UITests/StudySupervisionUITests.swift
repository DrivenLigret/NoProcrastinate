import XCTest

final class StudySupervisionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func plannedTask() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-study-records"]
        app.launch()
        XCTAssertTrue(app.buttons["NewTask"].waitForExistence(timeout: 10))
        app.buttons["NewTask"].tap()
        let title = app.textFields["TaskTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Draft essay\n")
        app.buttons["SaveTask"].tap()
        XCTAssertTrue(app.buttons["StudyTaskRow"].firstMatch.waitForExistence(timeout: 5))
        return app
    }

    func testRepeatedPostponementOffersAShorterFocusSession() {
        let app = plannedTask()
        app.buttons["StudyTaskRow"].firstMatch.tap()
        for _ in 0..<2 {
            app.buttons["PostponeTask"].tap()
            XCTAssertTrue(app.sheets.buttons["15 min"].waitForExistence(timeout: 5))
            app.sheets.buttons["15 min"].tap()
        }
        XCTAssertEqual(app.descendants(matching: .any)["PostponeCount"].value as? String, "2")
        XCTAssertTrue(app.descendants(matching: .any)["SuggestedFocus"].exists)
        capture("Suggested focus", app)
        app.buttons["StartFocus"].tap()
        let timer = app.staticTexts["FocusRemaining"]
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        let parts = timer.label.split(separator: ":").compactMap { Int($0) }
        XCTAssertEqual(parts.count, 2)
        if parts.count == 2 {
            let remaining = parts[0] * 60 + parts[1]
            XCTAssertGreaterThan(remaining, 800)
            XCTAssertLessThanOrEqual(remaining, 900)
        }
    }

    func testStudyRemindersCanBeEnabledAndRemoved() {
        let app = plannedTask()
        app.tabBars.buttons["Supervision"].tap()
        let toggle = app.switches["EnableReminders"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        else if app.alerts.buttons["Allow"].exists { app.alerts.buttons["Allow"].tap() }
        let scheduled = app.descendants(matching: .any)["ScheduledReminders"]
        capture("Reminder access", app)
        expectation(for: NSPredicate(format: "value == %@", "2"), evaluatedWith: scheduled)
        waitForExpectations(timeout: 10)
        capture("Supervision", app)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == %@", "0"), evaluatedWith: scheduled)
        waitForExpectations(timeout: 10)
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
