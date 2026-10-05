import SwiftUI

struct StudyRootView: View {
    private enum StudyTab: Hashable { case plan, focus, progress }
    @ObservedObject var planner: StudyPlannerViewModel
    @ObservedObject var focus: FocusViewModel
    @ObservedObject var progress: StudyProgressViewModel
    @State private var tab = StudyTab.plan
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            StudyPlanView(planner: planner, focus: focus, openFocus: { tab = .focus })
                .tabItem { Label("Plan", systemImage: "calendar") }.tag(StudyTab.plan)
            StudyFocusView(focus: focus, openPlan: { tab = .plan })
                .tabItem { Label("Focus", systemImage: "timer") }.tag(StudyTab.focus)
            StudyProgressView(progress: progress)
                .tabItem { Label("Progress", systemImage: "chart.bar") }.tag(StudyTab.progress)
        }
        .task { refresh() }
        .onChange(of: tab) { _, _ in refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    }

    private func refresh() {
        focus.load()
        planner.load()
        progress.load()
    }
}
