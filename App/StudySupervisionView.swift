import SwiftUI
import FamilyControls

struct StudySupervisionView: View {
    @ObservedObject var supervision: StudySupervisionViewModel
    @ObservedObject var focus: FocusViewModel
    @ObservedObject var widget: StudyWidgetPublisher
    @State private var choosingApps = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Smart supervision") {
                    Toggle("Smart supervision", isOn: Binding(get: { supervision.smart }, set: supervision.setSmart))
                        .accessibilityIdentifier("SmartSupervision")
                    LabeledContent("Needs a start", value: "\(supervision.needsStart)")
                }
                Section("Reminders") {
                    Toggle("Reminders", isOn: Binding(get: { supervision.reminders }, set: { value in Task { await supervision.setReminders(value) } }))
                        .disabled(supervision.busy)
                        .accessibilityIdentifier("EnableReminders")
                    LabeledContent("Scheduled", value: "\(supervision.scheduledCount)")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Scheduled")
                        .accessibilityValue("\(supervision.scheduledCount)")
                        .accessibilityIdentifier("ScheduledReminders")
                }
                Section("App limits") {
                    LabeledContent("Access", value: !FocusRestrictionController.deviceAvailable ? "iPhone required" : supervision.authorized ? "Allowed" : "Not allowed")
                    Button("Authorize") { Task { await supervision.authorize() } }
                        .disabled(!FocusRestrictionController.deviceAvailable || supervision.busy)
                    Button("Choose apps") { choosingApps = true }
                        .disabled(!supervision.authorized || focus.active != nil)
                    LabeledContent("Selected", value: "\(supervision.selectedCount)")
                    Toggle("During focus", isOn: Binding(get: { supervision.limits }, set: supervision.setLimits))
                        .disabled(!supervision.authorized || supervision.selectedCount == 0)
                }
                Section("Widget") {
                    LabeledContent("Access", value: widget.ready ? "Ready" : "Unavailable")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Widget")
                        .accessibilityValue(widget.ready ? "Ready" : "Unavailable")
                        .accessibilityIdentifier("WidgetAccess")
                }
            }
            .navigationTitle("Supervision")
            .familyActivityPicker(isPresented: $choosingApps, selection: $supervision.selection)
            .onChange(of: supervision.selection) { _, _ in supervision.saveSelection() }
            .alert("Supervision", isPresented: Binding(get: { supervision.error != nil }, set: { if !$0 { supervision.error = nil } })) {
                Button("OK", role: .cancel) { supervision.error = nil }
            } message: { Text(supervision.error ?? "") }
        }
    }
}
