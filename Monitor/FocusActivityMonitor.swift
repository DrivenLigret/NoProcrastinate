import Foundation
import DeviceActivity
import ManagedSettings

final class FocusActivityMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard activity.rawValue == FocusLease.activityName else { return }
        let settings = ManagedSettingsStore(named: ManagedSettingsStore.Name(FocusLease.settingsName))
        do {
            try SharedContainer.focusStore().update { lease in
                guard let current = lease, current.endsAt <= Date() else { return }
                settings.clearAllSettings()
                lease = nil
            }
        } catch { settings.clearAllSettings() }
    }
}
