import SwiftUI
import NoProcrastinateCore

struct StudyInboxView: View {
    @ObservedObject var inbox: StudyInboxViewModel
    @ObservedObject var planner: StudyPlannerViewModel
    @ObservedObject var supervision: StudySupervisionViewModel
    @State private var selected: StudyResource?
    @State private var discarding: StudyResource?

    var body: some View {
        NavigationStack {
            Group {
                if inbox.resources.isEmpty {
                    ContentUnavailableView("No shared resources", systemImage: "tray", description: Text("Share a link or text to NoProcrastinate."))
                        .accessibilityIdentifier("EmptyInbox")
                } else {
                    List(inbox.resources) { resource in
                        Button { selected = resource } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(resource.title).font(.headline)
                                Text(resource.content).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }.padding(.vertical, 6)
                        }
                        .accessibilityIdentifier("InboxResource")
                        .swipeActions { Button("Delete", role: .destructive) { discarding = resource } }
                    }
                }
            }
            .navigationTitle("Inbox")
            .task { inbox.load() }
            .refreshable { inbox.load() }
            .sheet(item: $selected) { resource in
                PlanStudyTaskView(planner: planner, resource: resource) { title, start, deadline, minutes in
                    try inbox.plan(resource, title: title, start: start, deadline: deadline, minutes: minutes)
                    planner.load()
                    supervision.refresh()
                }
            }
            .confirmationDialog("Delete resource?", isPresented: Binding(get: { discarding != nil }, set: { if !$0 { discarding = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let discarding { inbox.discard(discarding) }
                    discarding = nil
                }
            }
            .alert("Inbox", isPresented: Binding(get: { inbox.error != nil }, set: { if !$0 { inbox.error = nil } })) {
                Button("OK", role: .cancel) { inbox.error = nil }
            } message: { Text(inbox.error ?? "") }
        }
    }
}
