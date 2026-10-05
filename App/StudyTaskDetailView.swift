import SwiftUI
import NoProcrastinateCore

struct StudyTaskDetailView: View {
    @ObservedObject var planner: StudyPlannerViewModel
    @ObservedObject var focus: FocusViewModel
    let taskID: UUID
    let openFocus: () -> Void
    @State private var failure: String?

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
                        LabeledContent("Status", value: task.completedAt != nil ? "Completed" : task.plannedStart < Date() ? "Overdue" : "Planned")
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
        .alert("Task", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { failure = nil }
        } message: { Text(failure ?? "") }
    }
}
