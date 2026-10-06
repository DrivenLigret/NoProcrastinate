import UIKit
import SwiftUI

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareResourceViewModel(context: extensionContext)
        let host = UIHostingController(rootView: ShareResourceView(model: model).environment(\.locale, Locale(identifier: "en")))
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        preferredContentSize = CGSize(width: 400, height: 420)
    }
}

@MainActor
final class ShareResourceViewModel: ObservableObject {
    @Published var title = ""
    @Published private(set) var resource: SharedStudyResource?
    @Published private(set) var loading = true
    @Published private(set) var saving = false
    @Published var error: String?
    private let context: NSExtensionContext?

    init(context: NSExtensionContext?) { self.context = context }

    func load() async {
        defer { loading = false }
        do {
            let items = context?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
            let resource = try await StudyResourceLoader.load(items: items)
            title = resource.title
            self.resource = resource
        } catch { self.error = (error as? SharedResourceFailure)?.localizedDescription ?? SharedResourceFailure.unsupported.localizedDescription }
    }

    func save() {
        guard let resource, !saving else { return }
        saving = true
        do {
            let value = SharedStudyResource(id: resource.id, title: title.trimmingCharacters(in: .whitespacesAndNewlines), content: resource.content, kind: resource.kind, receivedAt: resource.receivedAt)
            try SharedStudyResourceStore.appGroup().save(value)
            context?.completeRequest(returningItems: nil, completionHandler: nil)
        } catch {
            saving = false
            self.error = (error as? SharedResourceFailure)?.localizedDescription ?? SharedResourceFailure.unavailable.localizedDescription
        }
    }

    func cancel() {
        context?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}

struct ShareResourceView: View {
    @ObservedObject var model: ShareResourceViewModel
    @FocusState private var editingTitle: Bool

    var body: some View {
        NavigationStack {
            Form {
                if model.loading { ProgressView() }
                if let resource = model.resource {
                    TextField("Task", text: $model.title)
                        .accessibilityIdentifier("SharedTaskTitle")
                        .focused($editingTitle)
                        .submitLabel(.done)
                        .onSubmit { editingTitle = false }
                    Text(resource.content).font(.callout).lineLimit(5)
                        .accessibilityIdentifier("SharedSource")
                }
            }
            .navigationTitle("NoProcrastinate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.cancel() }.disabled(model.saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { model.save() }
                        .accessibilityIdentifier("SaveResource")
                        .disabled(model.resource == nil || model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.saving)
                }
            }
            .task { await model.load() }
            .alert("Share", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK", role: .cancel) { model.error = nil }
            } message: { Text(model.error ?? "") }
        }.tint(Color(red: 0.08, green: 0.43, blue: 0.39))
    }
}
