import Foundation
import Combine
import WidgetKit
import NoProcrastinateCore

final class StudyWidgetPublisher: ObservableObject {
    @Published private(set) var ready = false
    private let repository: (any StudyRepository)?
    private let directory: URL?
    init(repository: (any StudyRepository)?) {
        self.repository = repository
        directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedContainer.identifier)
    }

    func publish() {
        do {
            guard let directory, let repository else { throw SharedStudyStorageFailure.unavailable }
            let now = Date()
            let state = try ReviewStudyWidget(repository: repository).execute(at: now)
            let tasks = state.tasks.prefix(8).map { WidgetStudyTask(id: $0.id, title: $0.title, plannedStart: $0.plannedStart, minutes: $0.focusMinutes) }
            let focus = state.focus.map { session in
                WidgetFocusSession(taskID: session.taskID, title: state.tasks.first(where: { $0.id == session.taskID })?.title ?? "Focus", startedAt: session.startedAt, endsAt: session.expectedEnd)
            }
            let snapshot = StudyWidgetSnapshot(generatedAt: now, tasks: tasks, focus: focus, completedToday: state.completedToday, focusSecondsToday: state.focusSecondsToday)
            try StudyWidgetSnapshotStore(directory: directory).save(snapshot)
            ready = true
            WidgetCenter.shared.reloadTimelines(ofKind: StudyWidgetSnapshot.kind)
        } catch { ready = false }
    }
}

final class WidgetPublishingStudyRepository: StudyRepository {
    private let repository: any StudyRepository
    private let publisher: StudyWidgetPublisher
    init(repository: any StudyRepository, publisher: StudyWidgetPublisher) {
        self.repository = repository
        self.publisher = publisher
    }
    func tasks() throws -> [StudyTask] { try repository.tasks() }
    func task(id: UUID) throws -> StudyTask? { try repository.task(id: id) }
    func overdueTasks(at date: Date) throws -> [StudyTask] { try repository.overdueTasks(at: date) }
    func sessions() throws -> [FocusSession] { try repository.sessions() }
    func save(_ task: StudyTask) throws { try repository.save(task); publisher.publish() }
    func save(_ session: FocusSession) throws { try repository.save(session); publisher.publish() }
}
