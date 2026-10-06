import Foundation

struct SharedStudyResource: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case link, text }
    let id: UUID
    let title: String
    let content: String
    let kind: Kind
    let receivedAt: Date

    func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SharedResourceFailure.missingTitle }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SharedResourceFailure.unsupported }
        guard content.count <= 10_000 else { throw SharedResourceFailure.tooLong }
        if kind == .link {
            guard let url = URL(string: content), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty else { throw SharedResourceFailure.unsupported }
        }
    }
}

enum SharedResourceFailure: Error, LocalizedError {
    case unavailable, unsupported, tooLong, missingTitle
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Inbox unavailable. Reopen and retry."
        case .unsupported: return "Share a web link or text."
        case .tooLong: return "Share up to 10,000 characters."
        case .missingTitle: return "Add a task title."
        }
    }
}

struct SharedStudyResourceStore {
    let directory: URL

    static func appGroup() throws -> SharedStudyResourceStore {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedContainer.identifier) else { throw SharedResourceFailure.unavailable }
        return SharedStudyResourceStore(directory: root.appendingPathComponent("StudyInbox", isDirectory: true))
    }

    func save(_ resource: SharedStudyResource) throws {
        try resource.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(resource).write(to: location(resource.id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func resources() throws -> [SharedStudyResource] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        var resources: [SharedStudyResource] = []
        for file in files {
            do {
                let resource = try JSONDecoder().decode(SharedStudyResource.self, from: Data(contentsOf: file))
                guard file.lastPathComponent == location(resource.id).lastPathComponent else { throw SharedResourceFailure.unavailable }
                try resource.validate()
                resources.append(resource)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                continue
            }
        }
        return resources.sorted { $0.receivedAt == $1.receivedAt ? $0.id.uuidString < $1.id.uuidString : $0.receivedAt < $1.receivedAt }
    }

    func remove(id: UUID) throws {
        let file = location(id)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    private func location(_ id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString + ".json")
    }
}
