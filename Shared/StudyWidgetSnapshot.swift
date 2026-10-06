import Foundation

struct WidgetStudyTask: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let plannedStart: Date
    let minutes: Int
    var url: URL { URL(string: "noprocrastinate://task/\(id.uuidString)")! }
}

struct WidgetFocusSession: Codable, Equatable {
    let taskID: UUID
    let title: String
    let startedAt: Date
    let endsAt: Date
}

struct StudyWidgetSnapshot: Codable, Equatable {
    static let kind = "NoProcrastinateStudyWidget"
    let generatedAt: Date
    let tasks: [WidgetStudyTask]
    let focus: WidgetFocusSession?
    let completedToday: Int
    let focusSecondsToday: Int
    static let empty = StudyWidgetSnapshot(generatedAt: .distantPast, tasks: [], focus: nil, completedToday: 0, focusSecondsToday: 0)

    func activeFocus(at date: Date) -> WidgetFocusSession? {
        guard let focus, focus.startedAt <= date && focus.endsAt > date else { return nil }
        return focus
    }

    func destination(at date: Date) -> URL {
        if activeFocus(at: date) != nil { return URL(string: "noprocrastinate://focus")! }
        return tasks.first?.url ?? URL(string: "noprocrastinate://plan")!
    }
}

struct StudyWidgetSnapshotStore {
    let directory: URL
    func save(_ snapshot: StudyWidgetSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent("study-widget.json"), options: .atomic)
    }
    func read() throws -> StudyWidgetSnapshot {
        try JSONDecoder().decode(StudyWidgetSnapshot.self, from: Data(contentsOf: directory.appendingPathComponent("study-widget.json")))
    }
}
