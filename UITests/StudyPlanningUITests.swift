import XCTest

final class StudyPlanningUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testPlannedStudyTaskCanBeReviewedAfterAppRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-study-records"]
        app.launch()
        XCTAssertTrue(app.buttons["NewTask"].waitForExistence(timeout: 10))
        app.buttons["NewTask"].tap()
        let title = app.textFields["TaskTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Read chapter 2\n")
        capture("New task", app)
        app.buttons["SaveTask"].tap()
        XCTAssertTrue(app.buttons["StudyTaskRow"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["StudyTaskRow"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["TaskDetailTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["TaskDetailTitle"].label, "Read chapter 2")
        XCTAssertTrue(app.staticTexts["25 min"].exists)
        capture("Task", app)
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["StudyTaskRow"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["TaskCount"].label, "1 task")
        XCTAssertEqual(app.buttons["StudyTaskRow"].firstMatch.label, "Read chapter 2")
        capture("Plan", app)
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
