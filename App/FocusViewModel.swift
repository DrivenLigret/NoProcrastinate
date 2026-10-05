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
    private var heartbeat: AnyCancellable?

    init(repository: (any StudyRepository)?) {
        self.repository = repository
        heartbeat = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] now in
            self?.finishIfElapsed(at: now)
        }
    }

    func load() {
        guard let repository else { return }
        do {
            let restored = try RestoreFocusSession(repository: repository).execute(at: Date())
            let previous = try repository.sessions().last(where: { $0.endedAt != nil })
            let displayed = restored ?? previous
            let title = try displayed.flatMap { try repository.task(id: $0.taskID)?.title } ?? ""
            active = restored
            lastSession = previous
            taskTitle = title
        } catch {
            self.error = error.localizedDescription
        }
    }

    func start(taskID: UUID) throws {
        guard let repository else { throw StudyError.storageUnavailable }
        let title = try repository.task(id: taskID)?.title ?? ""
        let session = try StartFocusSession(repository: repository).execute(taskID: taskID, at: Date())
        taskTitle = title
        active = session
    }

    func stop(at now: Date = Date()) throws {
        guard let repository else { throw StudyError.storageUnavailable }
        guard let session = active else { throw FinishFocusSession.Failure.sessionMissing }
        let saved = try FinishFocusSession(repository: repository).execute(sessionID: session.id, at: now)
        lastSession = saved
        active = nil
    }

    func finishIfElapsed(at now: Date) {
        guard let session = active, session.expectedEnd <= now else { return }
        do { try stop(at: session.expectedEnd) } catch { self.error = error.localizedDescription }
    }
}
