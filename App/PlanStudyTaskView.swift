import SwiftUI

struct PlanStudyTaskView: View {
    @ObservedObject var planner: StudyPlannerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start = Date().addingTimeInterval(300)
    @State private var deadline = Date().addingTimeInterval(86400)
    @State private var minutes = 25
    @State private var failure: String?
    @FocusState private var editingTitle: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task", text: $title)
                        .accessibilityIdentifier("TaskTitle")
                        .focused($editingTitle)
                        .submitLabel(.done)
                        .onSubmit { editingTitle = false }
                }
                Section {
                    DatePicker("Start", selection: $start, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Deadline", selection: $deadline, in: start..., displayedComponents: [.date, .hourAndMinute])
                    Picker("Focus", selection: $minutes) {
                        ForEach([15, 25, 45, 60, 90, 120], id: \.self) { value in
                            Text("\(value) min").tag(value)
                        }
                    }
                }
            }
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try planner.plan(title: title, start: start, deadline: deadline, minutes: minutes)
                            dismiss()
                        } catch {
                            failure = error.localizedDescription
                        }
                    }
                    .accessibilityIdentifier("SaveTask")
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Plan", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) { failure = nil }
            } message: { Text(failure ?? "") }
        }
    }
}
