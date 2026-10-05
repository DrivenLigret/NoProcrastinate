import SwiftUI

struct StudyProgressView: View {
    @ObservedObject var progress: StudyProgressViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(progress.today.completedTasks)").font(.largeTitle.bold())
                            Text("Tasks completed").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Tasks completed")
                        .accessibilityValue("\(progress.today.completedTasks)")
                        .accessibilityIdentifier("TodayCompletedTasks")
                        VStack(alignment: .leading, spacing: 8) {
                            Text(duration(progress.today.focusSeconds)).font(.title.bold())
                            Text("Focus time").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Focus time")
                        .accessibilityValue(duration(progress.today.focusSeconds))
                        .accessibilityIdentifier("TodayFocusTime")
                    }
                    .padding(.vertical, 12)
                }
                Section("Last 7 days") {
                    LabeledContent("Tasks completed", value: "\(progress.lastSevenDays.completedTasks)")
                    LabeledContent("Focus time", value: duration(progress.lastSevenDays.focusSeconds))
                    LabeledContent("Focus completed", value: "\(progress.lastSevenDays.completedSessions)")
                    LabeledContent("Interrupted", value: "\(progress.lastSevenDays.interruptedSessions)")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Interrupted")
                        .accessibilityValue("\(progress.lastSevenDays.interruptedSessions)")
                        .accessibilityIdentifier("InterruptedSessions")
                }
                if !progress.records.isEmpty {
                    Section("Recent focus") {
                        ForEach(progress.records) { record in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(record.taskTitle).font(.headline)
                                HStack {
                                    Text(record.session.interrupted ? "Interrupted" : "Completed")
                                    Spacer()
                                    Text(duration(record.session.recordedSeconds))
                                }
                                .font(.subheadline).foregroundStyle(.secondary)
                                if let ended = record.session.endedAt {
                                    Text(ended, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                            .accessibilityIdentifier("FocusRecord")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Progress")
            .alert("Progress", isPresented: Binding(get: { progress.error != nil }, set: { if !$0 { progress.error = nil } })) {
                Button("OK", role: .cancel) { progress.error = nil }
            } message: { Text(progress.error ?? "") }
        }
    }

    private func duration(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) sec" : "\(seconds / 60) min"
    }
}
