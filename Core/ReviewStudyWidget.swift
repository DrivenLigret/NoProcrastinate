import Foundation

public struct StudyWidgetState {
    public let tasks: [StudyTask]
    public let focus: FocusSession?
    public let completedToday: Int
    public let focusSecondsToday: Int
}

public struct ReviewStudyWidget {
    public enum Failure: Error, LocalizedError {
        case invalidStudyDay
        public var errorDescription: String? { "Study summary unavailable. Reopen and retry." }
    }
    public let repository: any StudyRepository
    public init(repository: any StudyRepository) { self.repository = repository }

    public func execute(at now: Date, calendar: Calendar = .current) throws -> StudyWidgetState {
        let day = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: day) else { throw Failure.invalidStudyDay }
        let tasks = try repository.tasks().filter { $0.completedAt == nil }.sorted { $0.plannedStart < $1.plannedStart }
        let focus = try repository.sessions().first { $0.endedAt == nil && $0.startedAt <= now && $0.expectedEnd > now }
        let progress = try ReviewStudyProgress(repository: repository).execute(from: day, until: end)
        return StudyWidgetState(tasks: tasks, focus: focus, completedToday: progress.completedTasks, focusSecondsToday: progress.focusSeconds)
    }
}
