import Foundation

public struct StudyTask: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var plannedStart: Date
    public var deadline: Date
    public var focusMinutes: Int
    public var postponeCount: Int
    public var completedAt: Date?
    public var source: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, plannedStart: Date, deadline: Date, focusMinutes: Int = 25, postponeCount: Int = 0, completedAt: Date? = nil, source: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.plannedStart = plannedStart
        self.deadline = deadline
        self.focusMinutes = focusMinutes
        self.postponeCount = postponeCount
        self.completedAt = completedAt
        self.source = source
        self.createdAt = createdAt
    }
}

public struct FocusSession: Identifiable, Codable, Equatable {
    public var id: UUID
    public var taskID: UUID
    public var startedAt: Date
    public var plannedMinutes: Int
    public var endedAt: Date?
    public var interrupted: Bool

    public var expectedEnd: Date { startedAt.addingTimeInterval(Double(plannedMinutes * 60)) }
    public var recordedSeconds: Int {
        guard let endedAt else { return 0 }
        return max(0, min(plannedMinutes * 60, Int(endedAt.timeIntervalSince(startedAt))))
    }

    public init(id: UUID = UUID(), taskID: UUID, startedAt: Date, plannedMinutes: Int, endedAt: Date? = nil, interrupted: Bool = false) {
        self.id = id
        self.taskID = taskID
        self.startedAt = startedAt
        self.plannedMinutes = plannedMinutes
        self.endedAt = endedAt
        self.interrupted = interrupted
    }
}

public enum StudyError: Error, LocalizedError, Equatable {
    case missingTitle
    case startInPast
    case deadlineBeforeFocus
    case focusLength
    case taskMissing
    case taskComplete
    case focusAlreadyRunning
    case sessionMissing
    case sessionFinished
    case clockBeforeStart
    case finishFocusFirst
    case storageUnavailable

    public var errorDescription: String? {
        switch self {
        case .missingTitle: return "Add a task title."
        case .startInPast: return "Choose a future start."
        case .deadlineBeforeFocus: return "Allow enough time before the deadline."
        case .focusLength: return "Choose 15–120 focus minutes."
        case .taskMissing: return "Task unavailable. Choose another task."
        case .taskComplete: return "Task completed. Choose another task."
        case .focusAlreadyRunning: return "Finish the current focus first."
        case .sessionMissing: return "Focus unavailable. Start a new session."
        case .sessionFinished: return "Focus already saved. Start another session."
        case .clockBeforeStart: return "Check the device time and retry."
        case .finishFocusFirst: return "Stop focus before completing this task."
        case .storageUnavailable: return "Study records unavailable. Reopen and retry."
        }
    }
}
