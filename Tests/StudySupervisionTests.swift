import XCTest
@testable import NoProcrastinateCore

final class MockFocusRestrictions: FocusRestrictionService {
    enum Failure: Error { case denied }
    var protected: [UUID] = []
    var released: [UUID] = []
    var fails = false
    func protect(_ session: FocusSession) throws {
        if fails { throw Failure.denied }
        protected.append(session.id)
    }
    func release(sessionID: UUID) throws { released.append(sessionID) }
}

final class StudySupervisionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var repository: MockStudyRepository!
    override func setUp() { repository = MockStudyRepository() }

    private func task(start: Date? = nil) throws -> StudyTask {
        try PlanStudyTask(repository: repository).execute(title: "Draft essay", start: start ?? now.addingTimeInterval(300), deadline: now.addingTimeInterval(86400), minutes: 25, at: now)
    }

    func testPostponingMovesTheStudyStartAndRecordsTheDelay() throws {
        let planned = try task()
        let postponed = try PostponeStudyTask(repository: repository).execute(taskID: planned.id, until: now.addingTimeInterval(1800), at: now)
        XCTAssertEqual(postponed.plannedStart, now.addingTimeInterval(1800))
        XCTAssertEqual(postponed.postponeCount, 1)
    }

    func testPostponingCannotBringAFuturePlanEarlier() throws {
        let planned = try task(start: now.addingTimeInterval(3600))
        XCTAssertThrowsError(try PostponeStudyTask(repository: repository).execute(taskID: planned.id, until: now.addingTimeInterval(900), at: now)) {
            XCTAssertEqual($0 as? PostponeStudyTask.Failure, .notLater)
        }
    }

    func testPostponingRejectsACompletedStudyTask() throws {
        var planned = try task()
        planned.completedAt = now
        try repository.save(planned)
        XCTAssertThrowsError(try PostponeStudyTask(repository: repository).execute(taskID: planned.id, until: now.addingTimeInterval(1800), at: now)) {
            XCTAssertEqual($0 as? PostponeStudyTask.Failure, .taskComplete)
        }
    }

    func testPostponingPreservesTimeForFocusBeforeTheDeadline() throws {
        let planned = try task()
        XCTAssertThrowsError(try PostponeStudyTask(repository: repository).execute(taskID: planned.id, until: planned.deadline.addingTimeInterval(-60), at: now)) {
            XCTAssertEqual($0 as? PostponeStudyTask.Failure, .deadlineTooClose)
        }
    }

    func testPostponingRequiresEndingTheTasksActiveFocus() throws {
        let planned = try task()
        _ = try StartFocusSession(repository: repository).execute(taskID: planned.id, at: now)
        XCTAssertThrowsError(try PostponeStudyTask(repository: repository).execute(taskID: planned.id, until: now.addingTimeInterval(1800), at: now)) {
            XCTAssertEqual($0 as? PostponeStudyTask.Failure, .finishFocusFirst)
        }
    }

    func testRemindersExcludeCompletedTasksAndActiveFocus() throws {
        var done = try task()
        done.completedAt = now
        try repository.save(done)
        let active = try task()
        _ = try StartFocusSession(repository: repository).execute(taskID: active.id, at: now)
        XCTAssertTrue(try PrepareStudyReminders(repository: repository).execute(at: now, smart: true).isEmpty)
    }

    func testRepeatedPostponementSuggestsAShorterAndEarlierFollowUp() throws {
        var delayed = try task()
        delayed.postponeCount = 2
        try repository.save(delayed)
        let reminders = try PrepareStudyReminders(repository: repository).execute(at: now, smart: true)
        XCTAssertEqual(reminders.map(\.minutes), [15, 15])
        XCTAssertEqual(reminders.last?.fireDate, delayed.plannedStart.addingTimeInterval(300))
        XCTAssertEqual(try PrepareStudyReminders(repository: repository).execute(at: now, smart: false).first?.minutes, 25)
    }

    func testRemindersKeepOnlyTheEarliestBoundedStudyPrompts() throws {
        for index in 1...30 { _ = try task(start: now.addingTimeInterval(Double(index * 60))) }
        let reminders = try PrepareStudyReminders(repository: repository).execute(at: now, smart: true)
        XCTAssertEqual(reminders.count, 40)
        XCTAssertEqual(reminders.first?.fireDate, now.addingTimeInterval(60))
        XCTAssertEqual(reminders.map(\.fireDate), reminders.map(\.fireDate).sorted())
    }

    func testFailedProtectionDoesNotCreateAnActiveFocus() throws {
        let planned = try task()
        let restrictions = MockFocusRestrictions()
        restrictions.fails = true
        XCTAssertThrowsError(try StartFocusSession(repository: repository, restrictions: restrictions).execute(taskID: planned.id, at: now))
        XCTAssertTrue(repository.focusSessions.isEmpty)
    }

    func testFailedFocusSaveReleasesItsPreparedRestrictions() throws {
        let planned = try task()
        let restrictions = MockFocusRestrictions()
        repository.failsToSave = true
        XCTAssertThrowsError(try StartFocusSession(repository: repository, restrictions: restrictions).execute(taskID: planned.id, at: now))
        XCTAssertEqual(restrictions.protected, restrictions.released)
        XCTAssertEqual(restrictions.released.count, 1)
        XCTAssertTrue(repository.focusSessions.isEmpty)
    }

    func testStoppingFocusReleasesOnlyTheSavedSession() throws {
        let planned = try task()
        let restrictions = MockFocusRestrictions()
        let session = try StartFocusSession(repository: repository, restrictions: restrictions).execute(taskID: planned.id, minutes: 15, at: now)
        let ended = try FinishFocusSession(repository: repository, restrictions: restrictions).execute(sessionID: session.id, at: now.addingTimeInterval(60))
        XCTAssertEqual(restrictions.released, [session.id])
        XCTAssertEqual(ended.plannedMinutes, 15)
        XCTAssertTrue(ended.interrupted)
    }
}
