import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import NoProcrastinateCore

final class FocusRestrictionController: FocusRestrictionService {
    enum Failure: Error, LocalizedError {
        case deviceRequired, authorizationNeeded, appsNeeded, setupFailed
        var errorDescription: String? {
            switch self {
            case .deviceRequired: return "App limits require a physical iPhone."
            case .authorizationNeeded: return "Authorize App limits first."
            case .appsNeeded: return "Choose distracting apps first."
            case .setupFailed: return "App limits unavailable. Retry or switch them off."
            }
        }
    }
    static var deviceAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
    let preferences: StudySupervisionPreferences
    private(set) var authorized = false
    private let center = DeviceActivityCenter()
    private var activity: DeviceActivityName { DeviceActivityName(FocusLease.activityName) }
    private var settings: ManagedSettingsStore { ManagedSettingsStore(named: ManagedSettingsStore.Name(FocusLease.settingsName)) }

    init(preferences: StudySupervisionPreferences) { self.preferences = preferences }

    @MainActor func refreshAuthorization() {
        authorized = Self.deviceAvailable && AuthorizationCenter.shared.authorizationStatus == .approved
    }

    @MainActor func authorize() async throws {
        guard Self.deviceAvailable else { throw Failure.deviceRequired }
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refreshAuthorization()
        guard authorized else { throw Failure.authorizationNeeded }
    }

    func protect(_ session: FocusSession) throws {
        guard preferences.limits else { return }
        guard Self.deviceAvailable else { throw Failure.deviceRequired }
        guard authorized else { throw Failure.authorizationNeeded }
        guard let encoded = preferences.selection,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: encoded),
              !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty else { throw Failure.appsNeeded }
        let lease = FocusLease(sessionID: session.id, startedAt: session.startedAt, endsAt: session.expectedEnd, selection: encoded)
        do {
            try SharedContainer.focusStore().update { current in
                if current?.sessionID != session.id || !center.activities.contains(activity) {
                    let calendar = Calendar.current
                    var start = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: session.startedAt.addingTimeInterval(-1))
                    var end = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: session.expectedEnd.addingTimeInterval(1))
                    start.timeZone = calendar.timeZone
                    end.timeZone = calendar.timeZone
                    try center.startMonitoring(activity, during: DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false))
                }
                current = lease
                settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
                settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
                settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
                settings.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            }
        } catch {
            settings.clearAllSettings()
            center.stopMonitoring([activity])
            throw Failure.setupFailed
        }
    }

    func release(sessionID: UUID) throws {
        guard Self.deviceAvailable else { return }
        var released = false
        do {
            try SharedContainer.focusStore().update { lease in
                guard lease?.sessionID == sessionID else { return }
                settings.clearAllSettings()
                lease = nil
                released = true
            }
        } catch {
            settings.clearAllSettings()
            released = true
        }
        if released { center.stopMonitoring([activity]) }
    }

    func reconcile(with session: FocusSession?) throws {
        guard Self.deviceAvailable else { return }
        if let session, preferences.limits, authorized { try protect(session) }
        else { clear() }
    }

    func clear() {
        guard Self.deviceAvailable else { return }
        do {
            try SharedContainer.focusStore().update { lease in
                settings.clearAllSettings()
                lease = nil
            }
        } catch { settings.clearAllSettings() }
        center.stopMonitoring([activity])
    }
}
