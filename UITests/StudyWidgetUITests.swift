import XCTest

final class StudyWidgetUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testHomeScreenWidgetReadsThePlannedTaskAndOpensItsDetails() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-study-records"]
        app.launch()
        XCTAssertTrue(app.buttons["NewTask"].waitForExistence(timeout: 10))
        app.buttons["NewTask"].tap()
        let title = app.textFields["TaskTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Review chapter 5\n")
        app.buttons["SaveTask"].tap()
        XCTAssertTrue(app.buttons["StudyTaskRow"].firstMatch.waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = home.icons["NoProcrastinate"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 10))
        icon.press(forDuration: 1.5)
        XCTAssertTrue(home.buttons["Edit Home Screen"].waitForExistence(timeout: 5))
        home.buttons["Edit Home Screen"].tap()
        if home.buttons["Edit"].exists {
            home.buttons["Edit"].tap()
            XCTAssertTrue(home.buttons["Add Widget"].waitForExistence(timeout: 5))
            home.buttons["Add Widget"].tap()
        } else { home.buttons["Add"].tap() }
        if home.buttons["Continue"].exists { home.buttons["Continue"].tap() }
        let gallery = XCTAttachment(screenshot: home.screenshot())
        gallery.name = "Widget gallery"
        gallery.lifetime = .keepAlways
        add(gallery)
        let search = home.searchFields["Search Widgets"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        if home.buttons["Continue"].waitForExistence(timeout: 2) { home.buttons["Continue"].tap() }
        search.typeText("NoProcrastinate")
        let result = home.cells["NoProcrastinate"]
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        result.tap()
        let addWidget = home.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Widget")).firstMatch
        XCTAssertTrue(addWidget.waitForExistence(timeout: 10))
        capture("Small widget", home)
        let pager = home.pageIndicators.allElementsBoundByIndex.first { $0.frame.minY > home.frame.height * 0.86 && $0.frame.maxY < home.frame.height }
        XCTAssertNotNil(pager)
        pager?.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        let medium = home.buttons.matching(NSPredicate(format: "value CONTAINS %@", "Widget, Medium")).firstMatch
        XCTAssertTrue(medium.waitForExistence(timeout: 10))
        capture("Medium widget", home)
        addWidget.tap()
        if home.buttons["Done"].waitForExistence(timeout: 5) { home.buttons["Done"].tap() }
        let task = home.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Review chapter 5")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 30))
        let attachment = XCTAttachment(screenshot: home.screenshot())
        attachment.name = "Home widget"
        attachment.lifetime = .keepAlways
        add(attachment)
        task.tap()
        XCTAssertTrue(app.staticTexts["TaskDetailTitle"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["TaskDetailTitle"].label, "Review chapter 5")
        app.buttons["CompleteTask"].tap()
        XCUIDevice.shared.press(.home)
        let completed = home.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "1 done")).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 60))
        XCTAssertTrue(home.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Plan a task")).firstMatch.exists)
        capture("Updated medium widget", home)
        let progress = home.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Progress")).firstMatch
        progress.tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 10))
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
