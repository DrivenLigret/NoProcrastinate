import XCTest
@testable import NoProcrastinateCore

final class StudyWidgetTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1800000000)

    func testWidgetSummaryExcludesCompletedTasksAndSortsTheNextStart() throws {
        let repository = MockStudyRepository()
        let later = StudyTask(title: "Draft essay", plannedStart: now.addingTimeInterval(600), deadline: now.addingTimeInterval(7200), createdAt: now)
        let earlier = StudyTask(title: "Read chapter 2", plannedStart: now.addingTimeInterval(300), deadline: now.addingTimeInterval(7200), createdAt: now)
        let done = StudyTask(title: "Done", plannedStart: now, deadline: now.addingTimeInterval(7200), completedAt: now, createdAt: now)
        for task in [later, done, earlier] { try repository.save(task) }
        let state = try ReviewStudyWidget(repository: repository).execute(at: now)
        XCTAssertEqual(state.tasks.map(\.id), [earlier.id, later.id])
        XCTAssertEqual(state.completedToday, 1)
    }

    func testWidgetSummaryKeepsTheActiveFocusWithoutInventingRecordedTime() throws {
        let repository = MockStudyRepository()
        let task = StudyTask(title: "Read chapter 2", plannedStart: now, deadline: now.addingTimeInterval(7200), createdAt: now)
        try repository.save(task)
        let session = try StartFocusSession(repository: repository).execute(taskID: task.id, at: now)
        let state = try ReviewStudyWidget(repository: repository).execute(at: now.addingTimeInterval(60))
        XCTAssertEqual(state.focus?.id, session.id)
        XCTAssertEqual(state.focusSecondsToday, 0)
    }

    func testWidgetSummaryDoesNotShowAnExpiredSessionAsRunning() throws {
        let repository = MockStudyRepository()
        let task = StudyTask(title: "Read chapter 2", plannedStart: now, deadline: now.addingTimeInterval(7200), createdAt: now)
        try repository.save(task)
        _ = try StartFocusSession(repository: repository).execute(taskID: task.id, at: now)
        XCTAssertNil(try ReviewStudyWidget(repository: repository).execute(at: now.addingTimeInterval(1800)).focus)
    }
}
