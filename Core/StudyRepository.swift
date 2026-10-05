import Foundation

public protocol StudyRepository {
    func tasks() throws -> [StudyTask]
    func task(id: UUID) throws -> StudyTask?
    func overdueTasks(at date: Date) throws -> [StudyTask]
    func sessions() throws -> [FocusSession]
    func save(_ task: StudyTask) throws
    func save(_ session: FocusSession) throws
}
