import SwiftUI
import NoProcrastinateCore

struct StudyTaskDetailView: View {
    @ObservedObject var planner: StudyPlannerViewModel
    @ObservedObject var focus: FocusViewModel
    @ObservedObject var supervision: StudySupervisionViewModel
    let taskID: UUID
    let openFocus: () -> Void
    @State private var failure: String?
    @State private var postponing = false

    var body: some View {
        Group {
            if let task = planner.tasks.first(where: { $0.id == taskID }) {
                List {
                    Section {
                        Text(task.title)
                            .font(.title2.bold())
                            .padding(.vertical, 12)
                            .accessibilityIdentifier("TaskDetailTitle")
                    }
                    Section {
                        LabeledContent("Start") {
                            Text(task.plannedStart, format: .dateTime.month(.abbreviated).day().hour().minute())
                        }
                        LabeledContent("Deadline") {
                            Text(task.deadline, format: .dateTime.month(.abbreviated).day().hour().minute())
                        }
                        LabeledContent("Focus", value: "\(task.focusMinutes) min")
                        if supervision.smart && task.postponeCount >= 2 && task.completedAt == nil {
                            LabeledContent("Suggested focus", value: "\(supervision.suggestedMinutes(for: task)) min")
                                .accessibilityIdentifier("SuggestedFocus")
                        }
                        if task.postponeCount > 0 {
                            LabeledContent("Postponed", value: "\(task.postponeCount)")
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Postponed")
                                .accessibilityValue("\(task.postponeCount)")
                                .accessibilityIdentifier("PostponeCount")
                        }
                        LabeledContent("Status", value: task.completedAt != nil ? "Completed" : task.plannedStart < Date() ? "Overdue" : "Planned")
                    }
                    if let source = task.source {
                        Section("Source") {
                            if let url = URL(string: source), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
                                Link(source, destination: url).accessibilityIdentifier("TaskSource")
                            } else {
                                Text(source).textSelection(.enabled).accessibilityIdentifier("TaskSource")
                            }
                        }
                    }
                    if task.completedAt == nil {
                        Section {
                            Button(focus.active?.taskID == task.id ? "Resume focus" : "Start focus") {
                                do {
                                    if focus.active?.taskID != task.id { try focus.start(taskID: task.id) }
                                    openFocus()
                                } catch { failure = error.localizedDescription }
                            }
                            .accessibilityIdentifier("StartFocus")
                            Button("Complete") {
                                do {
                                    try planner.complete(taskID: task.id)
                                    focus.load()
                                } catch { failure = error.localizedDescription }
                            }
                            .accessibilityIdentifier("CompleteTask")
                            Button("Later") { postponing = true }
                                .accessibilityIdentifier("PostponeTask")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView("Task unavailable", systemImage: "calendar")
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Later", isPresented: $postponing, titleVisibility: .visible) {
            ForEach([15, 30], id: \.self) { minutes in
                Button("\(minutes) min") {
                    do { try planner.postpone(taskID: taskID, minutes: minutes) }
                    catch { failure = error.localizedDescription }
                }
            }
        }
        .alert("Task", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { failure = nil }
        } message: { Text(failure ?? "") }
    }
}
