import SwiftUI
import NoProcrastinateCore

struct StudyPlanView: View {
    @ObservedObject var planner: StudyPlannerViewModel
    @ObservedObject var focus: FocusViewModel
    let openFocus: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingPlan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if planner.canPlan {
                        HStack {
                            Text("\(planner.tasks.count) \(planner.tasks.count == 1 ? "task" : "tasks")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("TaskCount")
                            Spacer()
                            if planner.overdueCount > 0 {
                                Text("\(planner.overdueCount) overdue")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.orange)
                            }
                        }
                        if planner.tasks.isEmpty {
                            ContentUnavailableView {
                                Label("Plan your first task", systemImage: "calendar.badge.plus")
                            } actions: {
                                Button("New task") { showingPlan = true }
                                    .buttonStyle(.borderedProminent)
                            }
                            .padding(.top, 80)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(planner.tasks) { task in
                                    NavigationLink(value: task.id) {
                                        StudyTaskRow(task: task)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(task.title)
                                    .accessibilityIdentifier("StudyTaskRow")
                                }
                            }
                        }
                    } else {
                        ContentUnavailableView("Study records unavailable", systemImage: "externaldrive", description: Text("Reopen to retry."))
                    }
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingPlan = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New task")
                        .accessibilityIdentifier("NewTask")
                        .disabled(!planner.canPlan)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                StudyTaskDetailView(planner: planner, focus: focus, taskID: id, openFocus: openFocus)
            }
            .sheet(isPresented: $showingPlan) { PlanStudyTaskView(planner: planner) }
            .alert("Plan", isPresented: Binding(get: { planner.error != nil }, set: { if !$0 { planner.error = nil } })) {
                Button("OK", role: .cancel) { planner.error = nil }
            } message: {
                Text(planner.error ?? "")
            }
            .task { planner.load() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { planner.load() } }
        }
    }
}

private struct StudyTaskRow: View {
    let task: StudyTask

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: task.completedAt == nil ? "calendar" : "checkmark.circle")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(Color(red: 0.08, green: 0.43, blue: 0.39).opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 7) {
                Text(task.title).font(.headline).foregroundStyle(.primary)
                Text(task.plannedStart, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(task.completedAt == nil ? "\(task.focusMinutes) min" : "Completed").font(.caption.weight(.medium)).foregroundStyle(.tint)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).padding(.top, 5)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}
