import XCTest
@testable import NoProcrastinateCore

final class MockStudyRepository: StudyRepository {
    var studyTasks: [StudyTask] = []
    var focusSessions: [FocusSession] = []
    var failsToSave = false
    func tasks() throws -> [StudyTask] { studyTasks.sorted { $0.plannedStart < $1.plannedStart } }
    func task(id: UUID) throws -> StudyTask? { studyTasks.first { $0.id == id } }
    func overdueTasks(at date: Date) throws -> [StudyTask] { studyTasks.filter { $0.completedAt == nil && $0.plannedStart < date } }
    func sessions() throws -> [FocusSession] { focusSessions }
    func save(_ task: StudyTask) throws {
        if failsToSave { throw StudyError.storageUnavailable }
        studyTasks.removeAll { $0.id == task.id }
        studyTasks.append(task)
    }
    func save(_ session: FocusSession) throws {
        if failsToSave { throw StudyError.storageUnavailable }
        focusSessions.removeAll { $0.id == session.id }
        focusSessions.append(session)
    }
}

final class StudyUseCaseTests: XCTestCase {
    var repository: MockStudyRepository!
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() { repository = MockStudyRepository() }

    @discardableResult
    func plan(minutes: Int = 25, title: String = "Read chapter 2") throws -> StudyTask {
        try PlanStudyTask(repository: repository).execute(title: title, start: now, deadline: now.addingTimeInterval(7200), minutes: minutes, at: now)
    }

    func testPlanningStudyTaskPersistsTrimmedTitle() throws {
        let task = try plan(title: "  Read chapter 2  ")
        XCTAssertEqual(task.title, "Read chapter 2")
        XCTAssertEqual(try repository.task(id: task.id), task)
    }

    func testPlanningStudyTaskRejectsBlankTitle() {
        XCTAssertThrowsError(try plan(title: " \n ")) { XCTAssertEqual($0 as? StudyError, .missingTitle) }
        XCTAssertTrue(repository.studyTasks.isEmpty)
    }

    func testPlanningStudyTaskAcceptsMinimumFocusInterval() throws {
        XCTAssertEqual(try plan(minutes: 15).focusMinutes, 15)
    }

    func testPlanningStudyTaskRejectsTooShortFocusInterval() {
        XCTAssertThrowsError(try plan(minutes: 14)) { XCTAssertEqual($0 as? StudyError, .focusLength) }
    }

    func testPlanningStudyTaskRejectsDeadlineBeforeFocusEnds() {
        XCTAssertThrowsError(try PlanStudyTask(repository: repository).execute(title: "Draft essay", start: now, deadline: now.addingTimeInterval(600), minutes: 25, at: now)) {
            XCTAssertEqual($0 as? StudyError, .deadlineBeforeFocus)
        }
    }

    func testPlanningStudyTaskAcceptsMaximumFocusInterval() throws {
        XCTAssertEqual(try plan(minutes: 120).focusMinutes, 120)
    }

    func testPlanningStudyTaskRejectsPastStart() {
        XCTAssertThrowsError(try PlanStudyTask(repository: repository).execute(title: "Draft essay", start: now.addingTimeInterval(-60), deadline: now.addingTimeInterval(7200), minutes: 25, at: now)) {
            XCTAssertEqual($0 as? StudyError, .startInPast)
        }
    }

    func testImportingSameStudyResourceDoesNotDuplicateTask() throws {
        let resourceID = UUID()
        let useCase = PlanStudyTask(repository: repository)
        let first = try useCase.execute(title: "Read chapter 2", start: now, deadline: now.addingTimeInterval(7200), minutes: 25, id: resourceID, at: now)
        let second = try useCase.execute(title: "Read chapter 2", start: now, deadline: now.addingTimeInterval(7200), minutes: 25, id: resourceID, at: now)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(repository.studyTasks.count, 1)
    }

    func testSavingFailureDoesNotCreateStudyTask() {
        repository.failsToSave = true
        XCTAssertThrowsError(try plan()) { XCTAssertEqual($0 as? StudyError, .storageUnavailable) }
        XCTAssertTrue(repository.studyTasks.isEmpty)
    }
}
