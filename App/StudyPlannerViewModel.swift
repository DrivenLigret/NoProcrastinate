import Foundation
import Combine
import NoProcrastinateCore

@MainActor
final class StudyPlannerViewModel: ObservableObject {
    @Published private(set) var tasks: [StudyTask] = []
    @Published private(set) var overdueCount = 0
    @Published var error: String?
    private let repository: (any StudyRepository)?
    var canPlan: Bool { repository != nil }

    init(repository: (any StudyRepository)?, initialError: String? = nil) {
        self.repository = repository
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
    }
}
