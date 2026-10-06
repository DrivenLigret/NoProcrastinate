import XCTest

final class StudyShareUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSharedWebLinkCanBeCancelledThenImportedAndReviewedAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-study-records"]
        app.launch()
        XCTAssertTrue(app.buttons["NewTask"].waitForExistence(timeout: 10))
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        if safari.buttons["Continue"].waitForExistence(timeout: 3) { safari.buttons["Continue"].tap() }
        let address = safari.textFields.matching(NSPredicate(format: "identifier IN %@ OR label == %@", ["TabBarItemTitle", "URL"], "Address")).firstMatch
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        address.tap()
        if safari.buttons["Continue"].waitForExistence(timeout: 2) { safari.buttons["Continue"].tap() }
        safari.textFields.firstMatch.typeText("https://example.com\n")
        XCTAssertTrue(safari.staticTexts["Example Domain"].waitForExistence(timeout: 30))
        openShare(safari)
        XCTAssertTrue(safari.textFields["SharedTaskTitle"].waitForExistence(timeout: 10))
        safari.buttons["Cancel"].tap()
        app.activate()
        app.tabBars.buttons["Inbox"].tap()
        XCTAssertTrue(app.staticTexts["No shared resources"].waitForExistence(timeout: 10))
        safari.activate()
        openShare(safari)
        let sharedTitle = safari.textFields["SharedTaskTitle"]
        XCTAssertTrue(sharedTitle.waitForExistence(timeout: 10))
        let resourceTitle = sharedTitle.value as? String
        XCTAssertFalse(resourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        capture("Share", safari)
        safari.buttons["SaveResource"].tap()
        XCTAssertTrue(safari.buttons["Share"].waitForExistence(timeout: 10))
        app.activate()
        let pending = app.buttons["InboxResource"].firstMatch
        XCTAssertTrue(pending.waitForExistence(timeout: 10))
        capture("Inbox", app)
        pending.tap()
        XCTAssertTrue(app.textFields["TaskTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["TaskTitle"].value as? String, resourceTitle)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        pending.tap()
        capture("Import", app)
        app.buttons["SaveTask"].tap()
        XCTAssertTrue(app.staticTexts["No shared resources"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Plan"].tap()
        XCTAssertEqual(app.staticTexts["TaskCount"].label, "1 task")
        app.buttons["StudyTaskRow"].firstMatch.tap()
        XCTAssertEqual(app.staticTexts["TaskDetailTitle"].label, resourceTitle)
        let source = app.descendants(matching: .any)["TaskSource"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(source.label.hasPrefix("https://example.com"))
        capture("Imported task", app)
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["StudyTaskRow"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["TaskCount"].label, "1 task")
        app.buttons["StudyTaskRow"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["TaskSource"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Inbox"].tap()
        XCTAssertTrue(app.staticTexts["No shared resources"].waitForExistence(timeout: 5))
    }

    private func openShare(_ safari: XCUIApplication) {
        XCTAssertTrue(safari.buttons["Share"].waitForExistence(timeout: 10))
        safari.buttons["Share"].tap()
        let target = safari.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "NoProcrastinate")).firstMatch
        if !target.waitForExistence(timeout: 3) {
            let more = safari.buttons["More"].firstMatch
            if more.exists { more.tap() }
            else { safari.cells["More"].firstMatch.tap() }
        }
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        target.tap()
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
