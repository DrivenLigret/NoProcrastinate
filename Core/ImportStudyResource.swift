import Foundation

public struct StudyResource: Identifiable, Equatable {
    public enum Kind: String { case link, text }
    public let id: UUID
    public let title: String
    public let content: String
    public let kind: Kind
    public let receivedAt: Date

    public init(id: UUID, title: String, content: String, kind: Kind, receivedAt: Date) {
        self.id = id
        self.title = title
        self.content = content
        self.kind = kind
        self.receivedAt = receivedAt
    }
}

public protocol StudyResourceInbox {
    func resources() throws -> [StudyResource]
    func remove(id: UUID) throws
}

public enum StudyResourceError: Error, LocalizedError, Equatable {
    case unsupportedLink
    case emptyContent
    case contentTooLong
    case inboxUnavailable

    public var errorDescription: String? {
        switch self {
        case .unsupportedLink: return "Share a web link."
        case .emptyContent: return "Share a link or text."
        case .contentTooLong: return "Share up to 10,000 characters."
        case .inboxUnavailable: return "Inbox unavailable. Reopen and retry."
        }
    }
}

public struct ImportStudyResource {
    public let repository: any StudyRepository
    public let inbox: any StudyResourceInbox

    public init(repository: any StudyRepository, inbox: any StudyResourceInbox) {
        self.repository = repository
        self.inbox = inbox
    }

    public func execute(resource: StudyResource, title: String, start: Date, deadline: Date, minutes: Int, at now: Date) throws -> StudyTask {
        if let existing = try repository.task(id: resource.id) {
            try inbox.remove(id: resource.id)
            return existing
        }
        let content = resource.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw StudyResourceError.emptyContent }
        guard content.count <= 10_000 else { throw StudyResourceError.contentTooLong }
        if resource.kind == .link {
            guard let url = URL(string: content), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty else { throw StudyResourceError.unsupportedLink }
        }
        let task = try PlanStudyTask(repository: repository).execute(title: title, start: start, deadline: deadline, minutes: minutes, source: content, id: resource.id, at: now)
        try inbox.remove(id: resource.id)
        return task
    }
}
