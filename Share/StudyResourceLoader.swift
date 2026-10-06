import Foundation
import UniformTypeIdentifiers

struct StudyResourceLoader {
    static func load(items: [NSExtensionItem]) async throws -> SharedStudyResource {
        let providers = items.flatMap { $0.attachments ?? [] }
        let provider = providers.first { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) } ?? providers.first { $0.hasItemConformingToTypeIdentifier(UTType.text.identifier) }
        let content: String
        let kind: SharedStudyResource.Kind
        if let provider {
            kind = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ? .link : .text
            let type = kind == .link ? UTType.url.identifier : provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) ? UTType.plainText.identifier : UTType.text.identifier
            content = try await withCheckedThrowingContinuation { continuation in
                provider.loadItem(forTypeIdentifier: type, options: nil) { item, failure in
                    if let failure { continuation.resume(throwing: failure) }
                    else if let url = item as? URL { continuation.resume(returning: url.absoluteString) }
                    else if let text = item as? String { continuation.resume(returning: text) }
                    else if let text = item as? NSAttributedString { continuation.resume(returning: text.string) }
                    else if let data = item as? Data, let text = String(data: data, encoding: .utf8) { continuation.resume(returning: text) }
                    else { continuation.resume(throwing: SharedResourceFailure.unsupported) }
                }
            }
        } else if let text = items.first?.attributedContentText?.string {
            content = text
            kind = .text
        } else { throw SharedResourceFailure.unsupported }
        let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggested = items.first?.attributedTitle?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = !suggested.isEmpty ? String(suggested.prefix(100)) : kind == .link ? URL(string: clean)?.host ?? "Study link" : String(clean.prefix(80))
        let resource = SharedStudyResource(id: UUID(), title: title, content: clean, kind: kind, receivedAt: Date())
        try resource.validate()
        return resource
    }
}
