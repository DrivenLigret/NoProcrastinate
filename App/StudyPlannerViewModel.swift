import Foundation
import Combine
import NoProcrastinateCore

@MainActor
final class StudyPlannerViewModel: ObservableObject {
    @Published private(set) var tasks: [StudyTask] = []
    @Published private(set) var overdueCount = 0
    @Published var error: String?
    private let repository: (any StudyRepository)?
    private let supervision: StudySupervisionViewModel
    var canPlan: Bool { repository != nil }

    init(repository: (any StudyRepository)?, supervision: StudySupervisionViewModel, initialError: String? = nil) {
        self.repository = repository
        self.supervision = supervision
        self.error = initialError
    }

    func load() {
        guard let repository else { return }
        do {
            let saved = try repository.tasks()
            let overdue = try repository.overdueTasks(at: Date())
            tasks = saved
            overdueCount = overdue.count
        } catch {
            self.error = error.localizedDescription
        }
    }

    func plan(title: String, start: Date, deadline: Date, minutes: Int) throws {
        guard let repository else { throw StudyError.storageUnavailable }
        let task = try PlanStudyTask(repository: repository).execute(title: title, start: start, deadline: deadline, minutes: minutes, at: Date())
        tasks.append(task)
        tasks.sort { $0.plannedStart < $1.plannedStart }
        supervision.refresh()
    }

    func complete(taskID: UUID) throws {
        guard let repository else { throw StudyError.storageUnavailable }
        let completed = try CompleteStudyTask(repository: repository).execute(taskID: taskID, at: Date())
        if let index = tasks.firstIndex(where: { $0.id == taskID }) { tasks[index] = completed }
        overdueCount = tasks.filter { $0.completedAt == nil && $0.plannedStart < Date() }.count
        supervision.refresh()
    }

    func postpone(taskID: UUID, minutes: Int) throws {
        guard let repository else { throw StudyError.storageUnavailable }
        let now = Date()
        let planned = try repository.task(id: taskID)?.plannedStart ?? now
        let postponed = try PostponeStudyTask(repository: repository).execute(taskID: taskID, until: max(now, planned).addingTimeInterval(Double(minutes * 60)), at: now)
        if let index = tasks.firstIndex(where: { $0.id == taskID }) { tasks[index] = postponed }
        tasks.sort { $0.plannedStart < $1.plannedStart }
        overdueCount = tasks.filter { $0.completedAt == nil && $0.plannedStart < Date() }.count
        supervision.refresh()
    }
}
