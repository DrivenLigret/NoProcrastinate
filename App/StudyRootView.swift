import SwiftUI

struct StudyRootView: View {
    private enum StudyTab: Hashable { case plan, focus, progress, inbox, supervision }
    @ObservedObject var planner: StudyPlannerViewModel
    @ObservedObject var focus: FocusViewModel
    @ObservedObject var progress: StudyProgressViewModel
    @ObservedObject var supervision: StudySupervisionViewModel
    @ObservedObject var widget: StudyWidgetPublisher
    @ObservedObject var inbox: StudyInboxViewModel
    @ObservedObject private var route = StudyNotificationRoute.shared
    @State private var requestedTaskID: UUID?
    @State private var tab = StudyTab.plan
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            StudyPlanView(planner: planner, focus: focus, supervision: supervision, requestedTaskID: $requestedTaskID, openFocus: { tab = .focus })
                .tabItem { Label("Plan", systemImage: "calendar") }.tag(StudyTab.plan)
            StudyFocusView(focus: focus, openPlan: { tab = .plan })
                .tabItem { Label("Focus", systemImage: "timer") }.tag(StudyTab.focus)
            StudyProgressView(progress: progress)
                .tabItem { Label("Progress", systemImage: "chart.bar") }.tag(StudyTab.progress)
            StudyInboxView(inbox: inbox, planner: planner, supervision: supervision)
                .tabItem { Label("Inbox", systemImage: "tray") }.tag(StudyTab.inbox)
                .badge(inbox.resources.count)
            StudySupervisionView(supervision: supervision, focus: focus, widget: widget)
                .tabItem { Label("Supervision", systemImage: "hand.raised") }.tag(StudyTab.supervision)
        }
        .task { refresh() }
        .onChange(of: tab) { _, _ in refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .onReceive(route.$taskID) { taskID in
            guard let taskID else { return }
            tab = .plan
            requestedTaskID = taskID
            route.taskID = nil
        }
        .onOpenURL { url in
            guard url.scheme == "noprocrastinate" else { return }
            switch url.host {
            case "focus": tab = .focus
            case "progress": tab = .progress
            case "inbox": tab = .inbox
            case "task":
                if let id = UUID(uuidString: url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) {
                    tab = .plan
                    requestedTaskID = id
                }
            default: tab = .plan
            }
        }
    }

    private func refresh() {
        supervision.refresh()
        focus.load()
        planner.load()
        progress.load()
        widget.publish()
        inbox.load()
    }
}
