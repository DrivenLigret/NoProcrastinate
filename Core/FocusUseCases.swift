import Foundation

public struct StartFocusSession {
    public enum Failure: Error, LocalizedError, Equatable {
        case taskMissing, taskComplete, focusLength, focusAlreadyRunning
        public var errorDescription: String? {
            switch self {
            case .taskMissing: return StudyError.taskMissing.errorDescription
            case .taskComplete: return StudyError.taskComplete.errorDescription
            case .focusLength: return StudyError.focusLength.errorDescription
            case .focusAlreadyRunning: return StudyError.focusAlreadyRunning.errorDescription
            }
        }
    }
    public let repository: any StudyRepository
    public let restrictions: (any FocusRestrictionService)?
    public init(repository: any StudyRepository, restrictions: (any FocusRestrictionService)? = nil) {
        self.repository = repository
        self.restrictions = restrictions
    }

    public func execute(taskID: UUID, minutes: Int? = nil, at now: Date) throws -> FocusSession {
        guard let task = try repository.task(id: taskID) else { throw Failure.taskMissing }
        guard task.completedAt == nil else { throw Failure.taskComplete }
        let duration = minutes ?? task.focusMinutes
        guard (15...120).contains(duration) else { throw Failure.focusLength }
        guard try RestoreFocusSession(repository: repository, restrictions: restrictions).execute(at: now) == nil else { throw Failure.focusAlreadyRunning }
        let session = FocusSession(taskID: taskID, startedAt: now, plannedMinutes: duration)
        try restrictions?.protect(session)
        do {
            try repository.save(session)
        } catch {
            try restrictions?.release(sessionID: session.id)
            throw error
        }
        return session
    }
}

public struct FinishFocusSession {
    public enum Failure: Error, LocalizedError, Equatable {
        case sessionMissing, sessionFinished, clockBeforeStart
        public var errorDescription: String? {
            switch self {
            case .sessionMissing: return StudyError.sessionMissing.errorDescription
            case .sessionFinished: return StudyError.sessionFinished.errorDescription
            case .clockBeforeStart: return StudyError.clockBeforeStart.errorDescription
            }
        }
    }
    public let repository: any StudyRepository
    public let restrictions: (any FocusRestrictionService)?
    public init(repository: any StudyRepository, restrictions: (any FocusRestrictionService)? = nil) {
        self.repository = repository
        self.restrictions = restrictions
    }

    public func execute(sessionID: UUID, at now: Date) throws -> FocusSession {
        guard var session = try repository.sessions().first(where: { $0.id == sessionID }) else { throw Failure.sessionMissing }
        guard session.endedAt == nil else { throw Failure.sessionFinished }
        guard now >= session.startedAt else { throw Failure.clockBeforeStart }
        session.endedAt = min(now, session.expectedEnd)
        session.interrupted = now < session.expectedEnd
        try repository.save(session)
        try restrictions?.release(sessionID: session.id)
        return session
    }
}

public struct RestoreFocusSession {
    public enum Failure: Error, LocalizedError, Equatable {
        case overlappingSessions, clockBeforeStart
        public var errorDescription: String? {
            switch self {
            case .overlappingSessions: return "Multiple focus sessions found. Reopen and retry."
            case .clockBeforeStart: return StudyError.clockBeforeStart.errorDescription
            }
        }
    }
    public let repository: any StudyRepository
    public let restrictions: (any FocusRestrictionService)?
    public init(repository: any StudyRepository, restrictions: (any FocusRestrictionService)? = nil) {
        self.repository = repository
        self.restrictions = restrictions
    }

    public func execute(at now: Date) throws -> FocusSession? {
        let unfinished = try repository.sessions().filter { $0.endedAt == nil }
        for session in unfinished where session.expectedEnd <= now {
            _ = try FinishFocusSession(repository: repository, restrictions: restrictions).execute(sessionID: session.id, at: session.expectedEnd)
        }
        let remaining = unfinished.filter { $0.expectedEnd > now }
        guard remaining.count <= 1 else { throw Failure.overlappingSessions }
        guard let session = remaining.first else { return nil }
        guard session.startedAt <= now else { throw Failure.clockBeforeStart }
        return session
    }
}

public struct CompleteStudyTask {
    public enum Failure: Error, LocalizedError, Equatable {
        case taskMissing, taskComplete, finishFocusFirst
        public var errorDescription: String? {
            switch self {
            case .taskMissing: return StudyError.taskMissing.errorDescription
            case .taskComplete: return StudyError.taskComplete.errorDescription
            case .finishFocusFirst: return StudyError.finishFocusFirst.errorDescription
            }
        }
    }
    public let repository: any StudyRepository
    public init(repository: any StudyRepository) { self.repository = repository }

    public func execute(taskID: UUID, at now: Date) throws -> StudyTask {
        guard var task = try repository.task(id: taskID) else { throw Failure.taskMissing }
        guard task.completedAt == nil else { throw Failure.taskComplete }
        _ = try RestoreFocusSession(repository: repository).execute(at: now)
        guard try repository.sessions().allSatisfy({ $0.taskID != taskID || $0.endedAt != nil }) else { throw Failure.finishFocusFirst }
        task.completedAt = now
        try repository.save(task)
        return task
    }
}
