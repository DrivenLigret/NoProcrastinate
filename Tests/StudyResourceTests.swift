import XCTest
@testable import NoProcrastinateCore

final class MockStudyResourceInbox: StudyResourceInbox {
    var pending: [StudyResource] = []
    var failsToRemove = false
    func resources() throws -> [StudyResource] { pending }
    func remove(id: UUID) throws {
        if failsToRemove { throw StudyResourceError.inboxUnavailable }
        pending.removeAll { $0.id == id }
    }
}

final class StudyResourceTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var repository: MockStudyRepository!
    var inbox: MockStudyResourceInbox!

    override func setUp() {
        repository = MockStudyRepository()
        inbox = MockStudyResourceInbox()
    }

    func resource(_ content: String = "https://example.com/chapter", kind: StudyResource.Kind = .link) -> StudyResource {
        let resource = StudyResource(id: UUID(), title: "Read chapter", content: content, kind: kind, receivedAt: now)
        inbox.pending.append(resource)
        return resource
    }

    func importResource(_ resource: StudyResource, title: String = "Read chapter", at date: Date? = nil) throws -> StudyTask {
        try ImportStudyResource(repository: repository, inbox: inbox).execute(resource: resource, title: title, start: now, deadline: now.addingTimeInterval(7200), minutes: 25, at: date ?? now)
    }

    func testImportingStudyLinkPersistsSourceBeforeRemovingInboxResource() throws {
        let shared = resource()
        let task = try importResource(shared)
        XCTAssertEqual(task.id, shared.id)
        XCTAssertEqual(task.source, shared.content)
        XCTAssertEqual(try repository.task(id: shared.id), task)
        XCTAssertTrue(inbox.pending.isEmpty)
    }

    func testImportingSharedNotesPreservesText() throws {
        let task = try importResource(resource("  Review limits\nSolve exercises 1–4  ", kind: .text))
        XCTAssertEqual(task.source, "Review limits\nSolve exercises 1–4")
    }

    func testImportingUnsupportedLinkRetainsInboxResource() {
        let shared = resource("file:///private/notes")
        XCTAssertThrowsError(try importResource(shared)) { XCTAssertEqual($0 as? StudyResourceError, .unsupportedLink) }
        XCTAssertEqual(inbox.pending, [shared])
        XCTAssertTrue(repository.studyTasks.isEmpty)
    }

    func testImportingBlankNotesRetainsInboxResource() {
        let shared = resource(" \n ", kind: .text)
        XCTAssertThrowsError(try importResource(shared)) { XCTAssertEqual($0 as? StudyResourceError, .emptyContent) }
        XCTAssertEqual(inbox.pending, [shared])
    }

    func testImportingOversizedNotesDoesNotCreateTask() {
        let shared = resource(String(repeating: "a", count: 10_001), kind: .text)
        XCTAssertThrowsError(try importResource(shared)) { XCTAssertEqual($0 as? StudyResourceError, .contentTooLong) }
        XCTAssertTrue(repository.studyTasks.isEmpty)
    }

    func testImportingMaximumLengthNotesSucceeds() throws {
        XCTAssertEqual(try importResource(resource(String(repeating: "a", count: 10_000), kind: .text)).source?.count, 10_000)
    }

    func testImportingWithoutTitleDoesNotConsumeResource() {
        let shared = resource()
        XCTAssertThrowsError(try importResource(shared, title: " ")) { XCTAssertEqual($0 as? StudyError, .missingTitle) }
        XCTAssertEqual(inbox.pending, [shared])
        XCTAssertTrue(repository.studyTasks.isEmpty)
    }

    func testFailedTaskSaveLeavesSharedResourcePending() {
        let shared = resource()
        repository.failsToSave = true
        XCTAssertThrowsError(try importResource(shared)) { XCTAssertEqual($0 as? StudyError, .storageUnavailable) }
        XCTAssertEqual(inbox.pending, [shared])
        XCTAssertTrue(repository.studyTasks.isEmpty)
    }

    func testRetryAfterInboxRemovalFailureKeepsOriginalTaskEvenAfterStartPasses() throws {
        let shared = resource()
        inbox.failsToRemove = true
        XCTAssertThrowsError(try importResource(shared)) { XCTAssertEqual($0 as? StudyResourceError, .inboxUnavailable) }
        XCTAssertEqual(repository.studyTasks.count, 1)
        XCTAssertEqual(inbox.pending, [shared])
        inbox.failsToRemove = false
        let retried = try importResource(shared, title: "Changed title", at: now.addingTimeInterval(3600))
        XCTAssertEqual(retried.title, "Read chapter")
        XCTAssertEqual(repository.studyTasks.count, 1)
        XCTAssertTrue(inbox.pending.isEmpty)
    }
}
