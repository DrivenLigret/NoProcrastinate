import SwiftUI
import NoProcrastinateCore

struct AppStudyResourceInbox: StudyResourceInbox {
    let store: SharedStudyResourceStore
    func resources() throws -> [StudyResource] {
        try store.resources().map { StudyResource(id: $0.id, title: $0.title, content: $0.content, kind: $0.kind == .link ? .link : .text, receivedAt: $0.receivedAt) }
    }
    func remove(id: UUID) throws { try store.remove(id: id) }
}

@MainActor
final class StudyInboxViewModel: ObservableObject {
    @Published private(set) var resources: [StudyResource] = []
    @Published var error: String?
    private let repository: (any StudyRepository)?
    private let inbox: (any StudyResourceInbox)?

    init(repository: (any StudyRepository)?) {
        self.repository = repository
        do {
            let inbox = AppStudyResourceInbox(store: try SharedStudyResourceStore.appGroup())
            if ProcessInfo.processInfo.arguments.contains("-reset-study-records") && ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                for resource in try inbox.resources() { try inbox.remove(id: resource.id) }
            }
            self.inbox = inbox
        } catch {
            self.inbox = nil
            self.error = StudyResourceError.inboxUnavailable.localizedDescription
        }
    }

    func load() {
        guard let inbox else { return }
        do { resources = try inbox.resources() }
        catch { error = StudyResourceError.inboxUnavailable.localizedDescription }
    }

    func plan(_ resource: StudyResource, title: String, start: Date, deadline: Date, minutes: Int) throws {
        guard let repository else { throw StudyError.storageUnavailable }
        guard let inbox else { throw StudyResourceError.inboxUnavailable }
        _ = try ImportStudyResource(repository: repository, inbox: inbox).execute(resource: resource, title: title, start: start, deadline: deadline, minutes: minutes, at: Date())
        load()
    }

    func discard(_ resource: StudyResource) {
        guard let inbox else { return }
        do { try inbox.remove(id: resource.id); load() }
        catch { error = StudyResourceError.inboxUnavailable.localizedDescription }
    }
}
