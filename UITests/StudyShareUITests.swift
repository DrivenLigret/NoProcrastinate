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
        if safari.buttons["Continue"].firstMatch.waitForExistence(timeout: 3) { safari.buttons["Continue"].firstMatch.tap() }
        let address = safari.textFields.matching(NSPredicate(format: "identifier IN %@ OR label == %@", ["TabBarItemTitle", "URL"], "Address")).firstMatch
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        address.tap()
        if safari.buttons["Continue"].firstMatch.waitForExistence(timeout: 2) { safari.buttons["Continue"].firstMatch.tap() }
        safari.textFields.firstMatch.typeText("https://example.com\n")
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "example.com"), object: address)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 30), .completed)
        openShare(safari)
        XCTAssertTrue(safari.textFields["SharedTaskTitle"].waitForExistence(timeout: 10))
        safari.buttons["Cancel"].tap()
        app.activate()
        selectTab("Inbox", app)
        XCTAssertTrue(app.staticTexts["No shared resources"].waitForExistence(timeout: 10))
        safari.activate()
        openShare(safari)
        let sharedTitle = safari.textFields["SharedTaskTitle"]
        XCTAssertTrue(sharedTitle.waitForExistence(timeout: 10))
        let resourceTitle = sharedTitle.value as? String
        XCTAssertFalse(resourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        capture("Share", safari)
        safari.buttons["SaveResource"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: safari.buttons["SaveResource"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 30), .completed)
        XCTAssertTrue(address.waitForExistence(timeout: 10))
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
        selectTab("Plan", app)
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
        selectTab("Inbox", app)
        XCTAssertTrue(app.staticTexts["No shared resources"].waitForExistence(timeout: 5))
    }

    private func selectTab(_ name: String, _ app: XCUIApplication) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        let selected = NSPredicate { element, _ in (element as? XCUIElement)?.isSelected == true }
        let first = XCTNSPredicateExpectation(predicate: selected, object: button)
        if XCTWaiter.wait(for: [first], timeout: 2) != .completed {
            button.tap()
            let retry = XCTNSPredicateExpectation(predicate: selected, object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [retry], timeout: 5), .completed)
        }
    }

    private func openShare(_ safari: XCUIApplication) {
        let target = safari.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "NoProcrastinate")).firstMatch
        if !target.exists {
            let share = safari.buttons["Share"].firstMatch
            if !share.waitForExistence(timeout: 3) || !share.isHittable {
                let tipClose = safari.buttons["xmark.circle.fill"].firstMatch
                if tipClose.waitForExistence(timeout: 3) { tipClose.tap() }
                let menu = safari.buttons["MoreMenuButton"].firstMatch
                XCTAssertTrue(menu.waitForExistence(timeout: 10))
                let menuReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: menu)
                XCTAssertEqual(XCTWaiter.wait(for: [menuReady], timeout: 30), .completed)
                menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            XCTAssertTrue(share.waitForExistence(timeout: 10))
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: share)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
            share.tap()
            if !target.waitForExistence(timeout: 3) {
                let more = safari.buttons["More"].firstMatch
                if more.exists { more.tap() }
                else { safari.cells["More"].firstMatch.tap() }
            }
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
