import SwiftUI
import WidgetKit

struct StudyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: StudyWidgetSnapshot
}

struct StudyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyWidgetEntry { preview() }
    func getSnapshot(in context: Context, completion: @escaping (StudyWidgetEntry) -> Void) {
        completion(context.isPreview ? preview() : StudyWidgetEntry(date: .now, snapshot: load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = load()
        var dates = [now]
        if let focus = snapshot.activeFocus(at: now) { dates.append(focus.endsAt.addingTimeInterval(0.1)) }
        if let start = snapshot.tasks.first?.plannedStart, start > now { dates.append(start) }
        let entries = dates.sorted().map { StudyWidgetEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(900))))
    }
    private func load() -> StudyWidgetSnapshot {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedContainer.identifier) else { return .empty }
        return (try? StudyWidgetSnapshotStore(directory: directory).read()) ?? .empty
    }
    private func preview() -> StudyWidgetEntry {
        let now = Date()
        let task = WidgetStudyTask(id: UUID(), title: "Read chapter 2", plannedStart: now.addingTimeInterval(300), minutes: 25)
        return StudyWidgetEntry(date: now, snapshot: StudyWidgetSnapshot(generatedAt: now, tasks: [task], focus: nil, completedToday: 1, focusSecondsToday: 1500))
    }
}

struct StudyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry
    private var today: Bool { Calendar.current.isDate(entry.date, inSameDayAs: entry.snapshot.generatedAt) }

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                if let focus = entry.snapshot.activeFocus(at: entry.date) {
                    Label("Focus", systemImage: "timer").font(.caption.weight(.semibold)).foregroundStyle(.teal)
                    Text(focus.title).font(.headline).lineLimit(2)
                    Text(timerInterval: focus.startedAt...focus.endsAt, countsDown: true)
                        .font(.title2.bold()).monospacedDigit().foregroundStyle(.teal)
                } else if let task = entry.snapshot.tasks.first {
                    Label(task.plannedStart <= entry.date ? "Start" : "Next", systemImage: "calendar")
                        .font(.caption.weight(.semibold)).foregroundStyle(.teal)
                    Text(task.title).font(.headline).lineLimit(2)
                    Text(task.plannedStart, format: .dateTime.hour().minute()).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(task.minutes) min").font(.caption).foregroundStyle(.teal)
                } else {
                    Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(.teal)
                    Text("Plan a task").font(.headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if family == .systemMedium {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Today").font(.caption).foregroundStyle(.secondary)
                    Text("\(today ? entry.snapshot.completedToday : 0) done").font(.headline)
                    Text("\(today ? entry.snapshot.focusSecondsToday / 60 : 0) min").font(.headline)
                    Link("Progress", destination: URL(string: "noprocrastinate://progress")!).font(.caption).foregroundStyle(.teal)
                }
                .frame(width: 95, alignment: .leading)
            }
        }
        .widgetURL(entry.snapshot.destination(at: entry.date))
        .containerBackground(Color(.systemGroupedBackground), for: .widget)
        .environment(\.locale, Locale(identifier: "en"))
    }
}

struct NoProcrastinateStudyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: StudyWidgetSnapshot.kind, provider: StudyWidgetProvider()) { entry in StudyWidgetView(entry: entry) }
            .configurationDisplayName("NoProcrastinate")
            .description("Tasks and focus.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NoProcrastinateWidgets: WidgetBundle {
    var body: some Widget { NoProcrastinateStudyWidget() }
}
