import XCTest

final class StudyFocusUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFocusRestoresAfterRelaunchAndCompletionAppearsInProgress() throws {
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
        app.buttons["StudyTaskRow"].firstMatch.tap()
        XCTAssertTrue(app.buttons["StartFocus"].waitForExistence(timeout: 5))
        app.buttons["StartFocus"].tap()
        let timer = app.staticTexts["FocusRemaining"]
        XCTAssertTrue(timer.waitForExistence(timeout: 10))
        let before = seconds(timer.label)
        XCTAssertGreaterThan(before, 1400)
        capture("Focus", app)
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["Focus"].tap()
        XCTAssertTrue(timer.waitForExistence(timeout: 10))
        XCTAssertLessThan(seconds(timer.label), before)
        XCTAssertTrue(app.staticTexts["Draft essay"].exists)
        app.buttons["StopFocus"].tap()
        XCTAssertTrue(app.buttons["ConfirmStopFocus"].waitForExistence(timeout: 5))
        app.buttons["ConfirmStopFocus"].tap()
        XCTAssertTrue(app.staticTexts["Focus stopped"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Plan"].tap()
        app.buttons["StudyTaskRow"].firstMatch.tap()
        app.buttons["CompleteTask"].tap()
        app.tabBars.buttons["Progress"].tap()
        let completedTasks = app.descendants(matching: .any)["TodayCompletedTasks"]
        XCTAssertTrue(completedTasks.waitForExistence(timeout: 5))
        XCTAssertEqual(completedTasks.value as? String, "1")
        let interruptions = app.descendants(matching: .any)["InterruptedSessions"]
        XCTAssertEqual(interruptions.value as? String, "1")
        XCTAssertTrue(app.staticTexts["Draft essay"].exists)
        capture("Progress", app)
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(completedTasks.waitForExistence(timeout: 5))
        XCTAssertEqual(completedTasks.value as? String, "1")
        XCTAssertTrue(app.staticTexts["Draft essay"].exists)
    }

    private func seconds(_ label: String) -> Int {
        let parts = label.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : -1
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
