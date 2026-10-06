import Foundation
import XCTest

final class StudyWidgetStorageTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws { directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true) }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testASeparateWidgetReaderSeesThePublishedStudyTask() throws {
        let now = Date()
        let task = WidgetStudyTask(id: UUID(), title: "Read chapter 2", plannedStart: now.addingTimeInterval(300), minutes: 25)
        let snapshot = StudyWidgetSnapshot(generatedAt: now, tasks: [task], focus: nil, completedToday: 1, focusSecondsToday: 600)
        try StudyWidgetSnapshotStore(directory: directory).save(snapshot)
        XCTAssertEqual(try StudyWidgetSnapshotStore(directory: directory).read(), snapshot)
        XCTAssertEqual(snapshot.destination(at: now).host, "task")
        XCTAssertEqual(snapshot.destination(at: now).lastPathComponent, task.id.uuidString)
    }

    func testTheWidgetStopsShowingFocusAtItsStoredEndTime() throws {
        let now = Date()
        let task = WidgetStudyTask(id: UUID(), title: "Read chapter 2", plannedStart: now, minutes: 25)
        let focus = WidgetFocusSession(taskID: task.id, title: task.title, startedAt: now, endsAt: now.addingTimeInterval(1500))
        let snapshot = StudyWidgetSnapshot(generatedAt: now, tasks: [task], focus: focus, completedToday: 0, focusSecondsToday: 0)
        try StudyWidgetSnapshotStore(directory: directory).save(snapshot)
        let saved = try StudyWidgetSnapshotStore(directory: directory).read()
        XCTAssertEqual(saved.destination(at: now).host, "focus")
        XCTAssertNil(saved.activeFocus(at: focus.endsAt))
        XCTAssertEqual(saved.destination(at: focus.endsAt).host, "task")
    }
}
