import Foundation

final class StudySupervisionPreferences {
    let defaults: UserDefaults
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            defaults = UserDefaults(suiteName: "NoProcrastinateUITests") ?? .standard
            if ProcessInfo.processInfo.arguments.contains("-reset-study-records") { defaults.removePersistentDomain(forName: "NoProcrastinateUITests") }
        } else { defaults = .standard }
        defaults.register(defaults: ["smartSupervision": true])
    }
    var smart: Bool {
        get { defaults.bool(forKey: "smartSupervision") }
        set { defaults.set(newValue, forKey: "smartSupervision") }
    }
    var reminders: Bool {
        get { defaults.bool(forKey: "studyReminders") }
        set { defaults.set(newValue, forKey: "studyReminders") }
    }
    var limits: Bool {
        get { defaults.bool(forKey: "focusAppLimits") }
        set { defaults.set(newValue, forKey: "focusAppLimits") }
    }
    var selection: Data? {
        get { defaults.data(forKey: "distractingApps") }
        set { defaults.set(newValue, forKey: "distractingApps") }
    }
}
