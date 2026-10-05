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
        let sessions = try repository.sessions().filter { $0.endedAt != nil }
        let completedTasks = tasks.filter {
            guard let completed = $0.completedAt else { return false }
            return completed >= start && completed < end
        }.count
        let focusSeconds = sessions.reduce(0) { total, session in
            guard let ended = session.endedAt else { return total }
            let lower = max(start, session.startedAt)
            let upper = min(end, min(ended, session.expectedEnd))
            return total + max(0, Int(upper.timeIntervalSince(lower)))
        }
        let attempts = sessions.filter {
            guard let ended = $0.endedAt else { return false }
            return ended >= start && ended < end
        }
        return StudyProgress(completedTasks: completedTasks, focusSeconds: focusSeconds, completedSessions: attempts.filter { !$0.interrupted }.count, interruptedSessions: attempts.filter(\.interrupted).count)
    }
}
