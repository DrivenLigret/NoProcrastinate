import XCTest

final class StudyStartupUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testIndependentStudyPlannerOpensWithNormalStorageAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        let newTask = app.buttons["NewTask"]
        XCTAssertTrue(newTask.waitForExistence(timeout: 15))
        XCTAssertTrue(newTask.isEnabled)
        XCTAssertEqual(app.state, .runningForeground)
        app.terminate()
        app.launch()
        XCTAssertTrue(newTask.waitForExistence(timeout: 15))
        XCTAssertTrue(newTask.isEnabled)
        newTask.tap()
        XCTAssertTrue(app.textFields["TaskTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["SaveTask"].isEnabled)
    }
}
