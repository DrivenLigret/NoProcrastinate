import Foundation
import XCTest
@testable import NoProcrastinateCore

final class StudyPersistenceTests: XCTestCase {
    private var directory: URL!
    private var store: URL { directory.appendingPathComponent("Study.sqlite") }
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testStudyTaskAndRelatedAttemptsSurviveStoreReopening() throws {
        let task = StudyTask(title: "Read chapter 2", plannedStart: now, deadline: now.addingTimeInterval(7200), createdAt: now)
        let first = FocusSession(taskID: task.id, startedAt: now, plannedMinutes: 25, endedAt: now.addingTimeInterval(600), interrupted: true)
        let second = FocusSession(taskID: task.id, startedAt: now.addingTimeInterval(1800), plannedMinutes: 15, endedAt: now.addingTimeInterval(2700))
        do {
            let repository = try CoreDataStudyRepository(storeURL: store)
            try repository.save(task)
            try repository.save(first)
            try repository.save(second)
        }
        let reopened = try CoreDataStudyRepository(storeURL: store)
        XCTAssertEqual(try reopened.task(id: task.id), task)
        XCTAssertEqual(try reopened.sessions(), [first, second])
    }

    func testOverduePredicateExcludesCompletedFutureAndExactStartTasks() throws {
        let repository = try CoreDataStudyRepository(storeURL: store)
        let overdue = StudyTask(title: "Delayed reading", plannedStart: now.addingTimeInterval(-60), deadline: now.addingTimeInterval(7200), createdAt: now)
        let completed = StudyTask(title: "Completed reading", plannedStart: now.addingTimeInterval(-60), deadline: now.addingTimeInterval(7200), completedAt: now, createdAt: now)
        let future = StudyTask(title: "Later reading", plannedStart: now.addingTimeInterval(60), deadline: now.addingTimeInterval(7200), createdAt: now)
        let exact = StudyTask(title: "Starting now", plannedStart: now, deadline: now.addingTimeInterval(7200), createdAt: now)
        for task in [overdue, completed, future, exact] { try repository.save(task) }
        XCTAssertEqual(try repository.overdueTasks(at: now).map(\.id), [overdue.id])
    }

    func testFocusAttemptWithoutStudyTaskIsRejectedWithoutSaving() throws {
        let repository = try CoreDataStudyRepository(storeURL: store)
        let orphan = FocusSession(taskID: UUID(), startedAt: now, plannedMinutes: 25)
        XCTAssertThrowsError(try repository.save(orphan)) { XCTAssertEqual($0 as? StudyError, .taskMissing) }
        XCTAssertTrue(try repository.sessions().isEmpty)
    }

    func testExpiredFocusIsFinalizedAtScheduledEndAfterStoreReopening() throws {
        let task = StudyTask(title: "Read chapter 2", plannedStart: now, deadline: now.addingTimeInterval(7200), createdAt: now)
        let session = FocusSession(taskID: task.id, startedAt: now, plannedMinutes: 25)
        do {
            let repository = try CoreDataStudyRepository(storeURL: store)
            try repository.save(task)
            try repository.save(session)
        }
        let reopened = try CoreDataStudyRepository(storeURL: store)
        XCTAssertNil(try RestoreFocusSession(repository: reopened).execute(at: now.addingTimeInterval(8000)))
        let saved = try XCTUnwrap(reopened.sessions().first)
        XCTAssertEqual(saved.endedAt, session.expectedEnd)
        XCTAssertEqual(saved.recordedSeconds, 1500)
        XCTAssertFalse(saved.interrupted)
    }
}
