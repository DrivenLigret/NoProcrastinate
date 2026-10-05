import SwiftUI
import NoProcrastinateCore

struct StudyTaskDetailView: View {
    @ObservedObject var planner: StudyPlannerViewModel
    let taskID: UUID

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
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView("Task unavailable", systemImage: "calendar")
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
    }
}
