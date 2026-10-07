import SwiftUI
import NoProcrastinateCore

struct StudyFocusView: View {
    @ObservedObject var focus: FocusViewModel
    let openPlan: () -> Void
    @State private var confirmingStop = false

    var body: some View {
        NavigationStack {
            Group {
                if let session = focus.active {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let totalSeconds = session.plannedMinutes * 60
                        let secondsUntilEnd = Int(ceil(session.expectedEnd.timeIntervalSince(timeline.date)))
                        let remaining = max(0, min(totalSeconds, secondsUntilEnd))
                        VStack(spacing: 28) {
                            Text(focus.taskTitle).font(.title2.bold()).multilineTextAlignment(.center)
                            ZStack {
                                Circle().stroke(Color.secondary.opacity(0.12), lineWidth: 14)
                                Circle().trim(from: 0, to: 1 - Double(remaining) / Double(session.plannedMinutes * 60))
                                    .stroke(Color(red: 0.08, green: 0.43, blue: 0.39), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .accessibilityIdentifier("FocusRemaining")
                            }
                            .frame(width: 240, height: 240)
                            LabeledContent("Ends") { Text(session.expectedEnd, style: .time) }
                                .font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: 260)
                            Button("Stop") { confirmingStop = true }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("StopFocus")
                        }
                        .padding(28)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if let session = focus.lastSession {
                    VStack(spacing: 18) {
                        Image(systemName: session.interrupted ? "pause.circle" : "checkmark.circle")
                            .font(.system(size: 54)).foregroundStyle(.tint)
                        Text(session.interrupted ? "Focus stopped" : "Focus complete").font(.title2.bold())
                        Text(focus.taskTitle).font(.headline)
                        Text(duration(session.recordedSeconds)).foregroundStyle(.secondary)
                        Button("Plan", action: openPlan).buttonStyle(.borderedProminent)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("Choose a task", systemImage: "timer")
                    } actions: {
                        Button("Plan", action: openPlan).buttonStyle(.borderedProminent)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Focus")
            .confirmationDialog("Stop focus?", isPresented: $confirmingStop, titleVisibility: .visible) {
                Button("Stop", role: .destructive) {
                    do { try focus.stop() } catch { focus.error = error.localizedDescription }
                }
                .accessibilityIdentifier("ConfirmStopFocus")
            }
            .alert("Focus", isPresented: Binding(get: { focus.error != nil }, set: { if !$0 { focus.error = nil } })) {
                Button("OK", role: .cancel) { focus.error = nil }
            } message: { Text(focus.error ?? "") }
        }
    }

    private func duration(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) sec" : "\(seconds / 60) min"
    }
}
