import Foundation
import Combine
import FamilyControls
import NoProcrastinateCore

@MainActor
final class StudySupervisionViewModel: ObservableObject {
    @Published private(set) var smart: Bool
    @Published private(set) var reminders: Bool
    @Published private(set) var limits: Bool
    @Published private(set) var authorized = false
    @Published private(set) var scheduledCount = 0
    @Published private(set) var needsStart = 0
    @Published private(set) var busy = false
    @Published var selection: FamilyActivitySelection
    @Published var error: String?
    let restrictions: FocusRestrictionController
    private let repository: (any StudyRepository)?
    private let preferences: StudySupervisionPreferences
    private let scheduler: StudyReminderScheduler

    init(repository: (any StudyRepository)?, preferences: StudySupervisionPreferences, restrictions: FocusRestrictionController) {
        self.repository = repository
        self.preferences = preferences
        self.restrictions = restrictions
        self.scheduler = StudyReminderScheduler()
        smart = preferences.smart
        reminders = preferences.reminders
        limits = preferences.limits
        selection = preferences.selection.flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) } ?? FamilyActivitySelection()
    }

    var selectedCount: Int { selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count }

    func suggestedMinutes(for task: StudyTask) -> Int { smart && task.postponeCount >= 2 ? 15 : task.focusMinutes }

    func setSmart(_ enabled: Bool) {
        preferences.smart = enabled
        smart = enabled
        refresh()
    }

    func setReminders(_ enabled: Bool) async {
        busy = true
        defer { busy = false }
        do {
            if enabled { try await scheduler.authorize() }
            preferences.reminders = enabled
            reminders = enabled
            try await synchronizeReminders()
        } catch {
            preferences.reminders = false
            reminders = false
            self.error = error.localizedDescription
            try? await scheduler.replace([], focus: nil, title: "")
        }
    }

    func authorize() async {
        busy = true
        defer { busy = false }
        do {
            try await restrictions.authorize()
            authorized = restrictions.authorized
        } catch { self.error = FocusRestrictionController.Failure.authorizationNeeded.localizedDescription }
    }

    func saveSelection() {
        do { preferences.selection = try JSONEncoder().encode(selection) }
        catch { self.error = FocusRestrictionController.Failure.appsNeeded.localizedDescription }
    }

    func setLimits(_ enabled: Bool) {
        do {
            if enabled {
                guard restrictions.authorized else { throw FocusRestrictionController.Failure.authorizationNeeded }
                guard selectedCount > 0 else { throw FocusRestrictionController.Failure.appsNeeded }
                if try repository?.sessions().contains(where: { $0.endedAt == nil && $0.expectedEnd > Date() }) == true { throw StudyError.finishFocusFirst }
            }
            preferences.limits = enabled
            limits = enabled
            if !enabled { restrictions.clear() }
        } catch { self.error = error.localizedDescription }
    }

    func refresh() {
        restrictions.refreshAuthorization()
        authorized = restrictions.authorized
        if !authorized && limits {
            preferences.limits = false
            limits = false
            restrictions.clear()
        }
        Task { @MainActor in
            do { try await synchronizeReminders() } catch { self.error = error.localizedDescription }
        }
    }

    private func synchronizeReminders() async throws {
        guard let repository else { return }
        needsStart = try repository.overdueTasks(at: Date()).count
        let reminders = preferences.reminders ? try PrepareStudyReminders(repository: repository).execute(at: Date(), smart: preferences.smart) : []
        let active = try repository.sessions().first { $0.endedAt == nil && $0.expectedEnd > Date() }
        let title = try active.flatMap { try repository.task(id: $0.taskID)?.title } ?? ""
        try await scheduler.replace(reminders, focus: preferences.reminders ? active : nil, title: title)
        scheduledCount = await scheduler.count()
    }
}
