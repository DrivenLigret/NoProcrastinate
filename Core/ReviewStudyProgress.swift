import Foundation

public struct StudyProgress: Equatable {
    public let completedTasks: Int
    public let focusSeconds: Int
    public let completedSessions: Int
    public let interruptedSessions: Int
    public static let zero = StudyProgress(completedTasks: 0, focusSeconds: 0, completedSessions: 0, interruptedSessions: 0)
}

public struct ReviewStudyProgress {
    public enum Failure: Error, LocalizedError, Equatable {
        case invalidStudyPeriod
        public var errorDescription: String? { "Choose a valid study period." }
    }
    public let repository: any StudyRepository
    public init(repository: any StudyRepository) { self.repository = repository }

    public func execute(from start: Date, until end: Date) throws -> StudyProgress {
        guard end > start else { throw Failure.invalidStudyPeriod }
        let tasks = try repository.tasks()
        let sessions = try repository.sessions()
        var completedTasks = 0
        var focusSeconds = 0
        var completedSessions = 0
        var interruptedSessions = 0
        for task in tasks {
            if let completed = task.completedAt, completed >= start && completed < end {
                completedTasks += 1
            }
        }
        for session in sessions {
            guard let ended = session.endedAt else { continue }
            let lower = max(start, session.startedAt)
            let upper = min(end, min(ended, session.expectedEnd))
            focusSeconds += max(0, Int(upper.timeIntervalSince(lower)))
            if ended >= start && ended < end {
                if session.interrupted {
                    interruptedSessions += 1
                } else {
                    completedSessions += 1
                }
            }
        }
        return StudyProgress(completedTasks: completedTasks, focusSeconds: focusSeconds, completedSessions: completedSessions, interruptedSessions: interruptedSessions)
    }
}
