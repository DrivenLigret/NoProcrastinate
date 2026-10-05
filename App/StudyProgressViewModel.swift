import Foundation
import Combine
import NoProcrastinateCore

struct StudyFocusRecord: Identifiable {
    let session: FocusSession
    let taskTitle: String
    var id: UUID { session.id }
}

@MainActor
final class StudyProgressViewModel: ObservableObject {
    @Published private(set) var today = StudyProgress.zero
    @Published private(set) var lastSevenDays = StudyProgress.zero
    @Published private(set) var records: [StudyFocusRecord] = []
    @Published var error: String?
    private let repository: (any StudyRepository)?

    init(repository: (any StudyRepository)?) { self.repository = repository }

    func load() {
        guard let repository else { return }
        do {
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: Date())
            guard let end = calendar.date(byAdding: .day, value: 1, to: day),
                  let week = calendar.date(byAdding: .day, value: -6, to: day) else { throw ReviewStudyProgress.Failure.invalidStudyPeriod }
            let review = ReviewStudyProgress(repository: repository)
            let daySummary = try review.execute(from: day, until: end)
            let weekSummary = try review.execute(from: week, until: end)
            let titles = Dictionary(uniqueKeysWithValues: try repository.tasks().map { ($0.id, $0.title) })
            let sessions = try repository.sessions().filter {
                guard let ended = $0.endedAt else { return false }
                return ended >= week && ended < end
            }.sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
            today = daySummary
            lastSevenDays = weekSummary
            records = sessions.prefix(5).map { StudyFocusRecord(session: $0, taskTitle: titles[$0.taskID] ?? "Task") }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
