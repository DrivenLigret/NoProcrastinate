import Foundation

public struct PlanStudyTask {
    public typealias Failure = StudyError
    public let repository: any StudyRepository
    public init(repository: any StudyRepository) { self.repository = repository }

    public func execute(title: String, start: Date, deadline: Date, minutes: Int, source: String? = nil, id: UUID = UUID(), at now: Date) throws -> StudyTask {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw Failure.missingTitle }
        guard (15...120).contains(minutes) else { throw Failure.focusLength }
        guard start >= now else { throw Failure.startInPast }
        guard deadline >= start.addingTimeInterval(Double(minutes * 60)) else { throw Failure.deadlineBeforeFocus }
        if let existing = try repository.task(id: id) { return existing }
        let task = StudyTask(id: id, title: cleanTitle, plannedStart: start, deadline: deadline, focusMinutes: minutes, source: source, createdAt: now)
        try repository.save(task)
        return task
    }
}

