import Foundation
import Combine
import NoProcrastinateCore

@MainActor
final class FocusViewModel: ObservableObject {
    @Published private(set) var active: FocusSession?
    @Published private(set) var lastSession: FocusSession?
    @Published private(set) var taskTitle = ""
    @Published var error: String?
    private let repository: (any StudyRepository)?
    private let supervision: StudySupervisionViewModel
    private var heartbeat: AnyCancellable?

    init(repository: (any StudyRepository)?, supervision: StudySupervisionViewModel) {
        self.repository = repository
        self.supervision = supervision
        heartbeat = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] now in
            self?.finishIfElapsed(at: now)
        }
    }

    func load() {
        guard let repository else { return }
        do {
            supervision.restrictions.refreshAuthorization()
            let restored = try RestoreFocusSession(repository: repository, restrictions: supervision.restrictions).execute(at: Date())
            let previous = try repository.sessions().last(where: { $0.endedAt != nil })
            let displayed = restored ?? previous
            var title = ""
            if let displayed {
                title = try repository.task(id: displayed.taskID)?.title ?? ""
            }
            active = restored
            lastSession = previous
            taskTitle = title
            try supervision.restrictions.reconcile(with: restored)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func start(taskID: UUID) throws {
        guard let repository else { throw StudyError.storageUnavailable }
        guard let task = try repository.task(id: taskID) else { throw StartFocusSession.Failure.taskMissing }
        supervision.restrictions.refreshAuthorization()
        let session = try StartFocusSession(repository: repository, restrictions: supervision.restrictions).execute(taskID: taskID, minutes: supervision.suggestedMinutes(for: task), at: Date())
        taskTitle = task.title
        active = session
        supervision.refresh()
    }

    func stop(at now: Date = Date()) throws {
        guard let repository else { throw StudyError.storageUnavailable }
        guard let session = active else { throw FinishFocusSession.Failure.sessionMissing }
        let saved = try FinishFocusSession(repository: repository, restrictions: supervision.restrictions).execute(sessionID: session.id, at: now)
        lastSession = saved
        active = nil
        supervision.refresh()
    }

    func finishIfElapsed(at now: Date) {
        guard let session = active, session.expectedEnd <= now else { return }
        do { try stop(at: session.expectedEnd) } catch { self.error = error.localizedDescription }
    }
}
