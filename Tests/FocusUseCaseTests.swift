import XCTest
@testable import NoProcrastinateCore

final class FocusUseCaseTests: XCTestCase {
    private var repository: MockStudyRepository!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() { repository = MockStudyRepository() }

    private func studyTask() throws -> StudyTask {
        try PlanStudyTask(repository: repository).execute(title: "Read chapter 2", start: now, deadline: now.addingTimeInterval(7200), minutes: 25, at: now)
    }

    private func focusSession() throws -> FocusSession {
        let task = try studyTask()
        return try StartFocusSession(repository: repository).execute(taskID: task.id, at: now)
    }

    func testStartingFocusPersistsTheStudyTaskAndScheduledEnd() throws {
        let session = try focusSession()
        XCTAssertEqual(repository.focusSessions, [session])
        XCTAssertEqual(session.expectedEnd, now.addingTimeInterval(1500))
        XCTAssertNotNil(try repository.task(id: session.taskID))
    }

    func testStartingFocusRejectsACompletedStudyTask() throws {
        var task = try studyTask()
        task.completedAt = now
        try repository.save(task)
        XCTAssertThrowsError(try StartFocusSession(repository: repository).execute(taskID: task.id, at: now)) {
            XCTAssertEqual($0 as? StartFocusSession.Failure, .taskComplete)
        }
    }

    func testStartingFocusRejectsAMissingStudyTask() {
        XCTAssertThrowsError(try StartFocusSession(repository: repository).execute(taskID: UUID(), at: now)) {
            XCTAssertEqual($0 as? StartFocusSession.Failure, .taskMissing)
        }
    }

    func testStartingFocusRejectsOverlappingAttempts() throws {
        let session = try focusSession()
        XCTAssertThrowsError(try StartFocusSession(repository: repository).execute(taskID: session.taskID, at: now.addingTimeInterval(10))) {
            XCTAssertEqual($0 as? StartFocusSession.Failure, .focusAlreadyRunning)
        }
        XCTAssertEqual(repository.focusSessions.count, 1)
    }

    func testStartingFocusFinalizesAnExpiredAttemptFirst() throws {
        let session = try focusSession()
        let next = try StartFocusSession(repository: repository).execute(taskID: session.taskID, at: now.addingTimeInterval(1600))
        XCTAssertEqual(repository.focusSessions.first(where: { $0.id == session.id })?.endedAt, session.expectedEnd)
        XCTAssertEqual(repository.focusSessions.filter { $0.endedAt == nil }.map(\.id), [next.id])
    }

    func testStoppingFocusEarlyRecordsElapsedSecondsAndInterruption() throws {
        let session = try focusSession()
        let saved = try FinishFocusSession(repository: repository).execute(sessionID: session.id, at: now.addingTimeInterval(300))
        XCTAssertEqual(saved.recordedSeconds, 300)
        XCTAssertTrue(saved.interrupted)
        XCTAssertEqual(try repository.task(id: session.taskID)?.completedAt, nil)
    }

    func testReturningLongAfterFocusEndsDoesNotOvercountTime() throws {
        let session = try focusSession()
        let saved = try FinishFocusSession(repository: repository).execute(sessionID: session.id, at: now.addingTimeInterval(8000))
        XCTAssertEqual(saved.recordedSeconds, 1500)
        XCTAssertEqual(saved.endedAt, session.expectedEnd)
        XCTAssertFalse(saved.interrupted)
    }

    func testFinishingAtScheduledEndIsACompletedFocusAttempt() throws {
        let session = try focusSession()
        let saved = try FinishFocusSession(repository: repository).execute(sessionID: session.id, at: session.expectedEnd)
        XCTAssertFalse(saved.interrupted)
        XCTAssertEqual(saved.recordedSeconds, 1500)
    }

    func testFinishingFocusRejectsAClockBeforeItsStart() throws {
        let session = try focusSession()
        XCTAssertThrowsError(try FinishFocusSession(repository: repository).execute(sessionID: session.id, at: now.addingTimeInterval(-1))) {
            XCTAssertEqual($0 as? FinishFocusSession.Failure, .clockBeforeStart)
        }
        XCTAssertNil(repository.focusSessions.first?.endedAt)
    }

    func testFinishingFocusTwiceDoesNotReplaceTheSavedAttempt() throws {
        let session = try focusSession()
        let saved = try FinishFocusSession(repository: repository).execute(sessionID: session.id, at: now.addingTimeInterval(300))
        XCTAssertThrowsError(try FinishFocusSession(repository: repository).execute(sessionID: session.id, at: now.addingTimeInterval(600))) {
            XCTAssertEqual($0 as? FinishFocusSession.Failure, .sessionFinished)
        }
        XCTAssertEqual(repository.focusSessions, [saved])
    }

    func testCompletingStudyTaskRequiresEndingItsActiveFocus() throws {
        let session = try focusSession()
        XCTAssertThrowsError(try CompleteStudyTask(repository: repository).execute(taskID: session.taskID, at: now.addingTimeInterval(60))) {
            XCTAssertEqual($0 as? CompleteStudyTask.Failure, .finishFocusFirst)
        }
        XCTAssertNil(try repository.task(id: session.taskID)?.completedAt)
    }

    func testCompletingStudyTaskPreservesItsFocusHistory() throws {
        let session = try focusSession()
        let saved = try FinishFocusSession(repository: repository).execute(sessionID: session.id, at: now.addingTimeInterval(300))
        let completed = try CompleteStudyTask(repository: repository).execute(taskID: session.taskID, at: now.addingTimeInterval(400))
        XCTAssertEqual(completed.completedAt, now.addingTimeInterval(400))
        XCTAssertEqual(repository.focusSessions, [saved])
    }

    func testRestoringActiveFocusPreservesTheOriginalDeadline() throws {
        let session = try focusSession()
        let restored = try RestoreFocusSession(repository: repository).execute(at: now.addingTimeInterval(600))
        XCTAssertEqual(restored, session)
        XCTAssertEqual(restored?.expectedEnd.timeIntervalSince(now.addingTimeInterval(600)), 900)
    }

    func testRestoringExpiredFocusSavesOnlyItsPlannedDuration() throws {
        let session = try focusSession()
        XCTAssertNil(try RestoreFocusSession(repository: repository).execute(at: now.addingTimeInterval(8000)))
        XCTAssertEqual(repository.focusSessions.first?.recordedSeconds, 1500)
        XCTAssertFalse(repository.focusSessions.first?.interrupted ?? true)
    }

    func testStudyProgressClipsFocusTimeToTheRequestedDay() throws {
        let task = try studyTask()
        let session = FocusSession(taskID: task.id, startedAt: now.addingTimeInterval(-120), plannedMinutes: 25, endedAt: now.addingTimeInterval(180), interrupted: true)
        try repository.save(session)
        let progress = try ReviewStudyProgress(repository: repository).execute(from: now, until: now.addingTimeInterval(120))
        XCTAssertEqual(progress.focusSeconds, 120)
        XCTAssertEqual(progress.interruptedSessions, 0)
    }

    func testStudyProgressCountsTaskCompletionSeparatelyFromInterruptedFocus() throws {
        let session = try focusSession()
        _ = try FinishFocusSession(repository: repository).execute(sessionID: session.id, at: now.addingTimeInterval(300))
        _ = try CompleteStudyTask(repository: repository).execute(taskID: session.taskID, at: now.addingTimeInterval(400))
        let progress = try ReviewStudyProgress(repository: repository).execute(from: now, until: now.addingTimeInterval(7200))
        XCTAssertEqual(progress.completedTasks, 1)
        XCTAssertEqual(progress.focusSeconds, 300)
        XCTAssertEqual(progress.interruptedSessions, 1)
        XCTAssertEqual(progress.completedSessions, 0)
    }

    func testStudyProgressDoesNotTreatActiveTimerTimeAsSavedFocus() throws {
        _ = try focusSession()
        let progress = try ReviewStudyProgress(repository: repository).execute(from: now, until: now.addingTimeInterval(7200))
        XCTAssertEqual(progress.focusSeconds, 0)
        XCTAssertEqual(progress.completedTasks, 0)
    }

    func testStudyProgressRejectsAnEmptyStudyPeriod() {
        XCTAssertThrowsError(try ReviewStudyProgress(repository: repository).execute(from: now, until: now)) {
            XCTAssertEqual($0 as? ReviewStudyProgress.Failure, .invalidStudyPeriod)
        }
    }

    func testFailedFocusSaveDoesNotCreateAnActiveAttempt() throws {
        let task = try studyTask()
        repository.failsToSave = true
        XCTAssertThrowsError(try StartFocusSession(repository: repository).execute(taskID: task.id, at: now)) {
            XCTAssertEqual($0 as? StudyError, .storageUnavailable)
        }
        XCTAssertTrue(repository.focusSessions.isEmpty)
    }
}
