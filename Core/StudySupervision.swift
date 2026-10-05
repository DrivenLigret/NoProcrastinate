import Foundation

public protocol FocusRestrictionService {
    func protect(_ session: FocusSession) throws
    func release(sessionID: UUID) throws
}

public struct PostponeStudyTask {
    public enum Failure: Error, LocalizedError, Equatable {
        case taskMissing, taskComplete, startInPast, notLater, deadlineTooClose, finishFocusFirst
        public var errorDescription: String? {
            switch self {
            case .taskMissing: return StudyError.taskMissing.errorDescription
            case .taskComplete: return StudyError.taskComplete.errorDescription
            case .startInPast: return StudyError.startInPast.errorDescription
            case .notLater: return "Choose a later study start."
            case .deadlineTooClose: return "Not enough time before the deadline. Start focus now."
            case .finishFocusFirst: return StudyError.finishFocusFirst.errorDescription
            }
        }
    }
    public let repository: any StudyRepository
    public init(repository: any StudyRepository) { self.repository = repository }

    public func execute(taskID: UUID, until start: Date, at now: Date) throws -> StudyTask {
        guard var task = try repository.task(id: taskID) else { throw Failure.taskMissing }
        guard task.completedAt == nil else { throw Failure.taskComplete }
        guard start > now else { throw Failure.startInPast }
        guard start > task.plannedStart else { throw Failure.notLater }
        guard start.addingTimeInterval(Double(task.focusMinutes * 60)) <= task.deadline else { throw Failure.deadlineTooClose }
        guard try repository.sessions().allSatisfy({ $0.taskID != taskID || $0.endedAt != nil }) else { throw Failure.finishFocusFirst }
        task.plannedStart = start
        task.postponeCount += 1
        try repository.save(task)
        return task
    }
}

public struct StudyReminder: Identifiable, Equatable {
    public let id: String
    public let taskID: UUID
    public let title: String
    public let minutes: Int
    public let fireDate: Date
    public let isFollowUp: Bool
}

public struct PrepareStudyReminders {
    public enum Failure: Error, LocalizedError, Equatable {
        case reminderLimit
        public var errorDescription: String? { "Choose up to 40 reminders." }
    }
    public let repository: any StudyRepository
    public init(repository: any StudyRepository) { self.repository = repository }

    public func execute(at now: Date, smart: Bool, limit: Int = 40) throws -> [StudyReminder] {
        guard (1...40).contains(limit) else { throw Failure.reminderLimit }
        let sessions = try repository.sessions()
        var reminders: [StudyReminder] = []
        for task in try repository.tasks() where task.completedAt == nil {
            if sessions.contains(where: { $0.taskID == task.id && ($0.endedAt == nil || $0.startedAt >= task.plannedStart) }) { continue }
            let minutes = smart && task.postponeCount >= 2 ? 15 : task.focusMinutes
            let grace = smart && task.postponeCount >= 2 ? 5 : 15
            for (kind, date) in [(false, task.plannedStart), (true, task.plannedStart.addingTimeInterval(Double(grace * 60)))] where date > now {
                reminders.append(StudyReminder(id: "study.\(task.id).\(kind ? "nudge" : "start")", taskID: task.id, title: task.title, minutes: minutes, fireDate: date, isFollowUp: kind))
            }
        }
        return Array(reminders.sorted { $0.fireDate == $1.fireDate ? $0.id < $1.id : $0.fireDate < $1.fireDate }.prefix(limit))
    }
}
