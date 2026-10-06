import Foundation
import UserNotifications
import Combine
import NoProcrastinateCore

@MainActor
final class StudyNotificationRoute: ObservableObject {
    static let shared = StudyNotificationRoute()
    @Published var taskID: UUID?
}

final class StudyNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let value = response.notification.request.content.userInfo["taskID"] as? String,
              let taskID = UUID(uuidString: value) else { return }
        await MainActor.run { StudyNotificationRoute.shared.taskID = taskID }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@MainActor
final class StudyReminderScheduler {
    enum Failure: Error, LocalizedError {
        case permissionDenied, schedulingFailed
        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Allow reminders in Settings."
            case .schedulingFailed: return "Reminders unavailable. Reopen and retry."
            }
        }
    }
    private let center = UNUserNotificationCenter.current()
    private let delegate = StudyNotificationDelegate()
    private var tail: Task<Void, Error>?

    init() { center.delegate = delegate }

    func authorize() async throws {
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { throw Failure.permissionDenied }
    }

    func count() async -> Int {
        await center.pendingNotificationRequests().filter { Self.owns($0.identifier) }.count
    }

    func replace(_ reminders: [StudyReminder], focus: FocusSession?, title: String) async throws {
        let previous = tail
        let next = Task { @MainActor in
            _ = try? await previous?.value
            let pending = await self.center.pendingNotificationRequests()
            self.center.removePendingNotificationRequests(withIdentifiers: pending.filter { Self.owns($0.identifier) }.map(\.identifier))
            let delivered = await self.center.deliveredNotifications()
            self.center.removeDeliveredNotifications(withIdentifiers: delivered.filter { Self.owns($0.request.identifier) }.map { $0.request.identifier })
            do {
                for reminder in reminders {
                    let content = UNMutableNotificationContent()
                    content.title = "Start \(reminder.title)"
                    content.body = "\(reminder.isFollowUp ? "Try " : "")\(reminder.minutes) min"
                    content.sound = .default
                    content.userInfo = ["taskID": reminder.taskID.uuidString]
                    let interval = reminder.fireDate.timeIntervalSinceNow
                    if interval > 0 {
                        try await self.center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)))
                    }
                }
                if let focus, focus.expectedEnd > Date() {
                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = "Focus complete"
                    content.sound = .default
                    content.userInfo = ["taskID": focus.taskID.uuidString]
                    try await self.center.add(UNNotificationRequest(identifier: "focus.\(focus.id).end", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, focus.expectedEnd.timeIntervalSinceNow), repeats: false)))
                }
            } catch { throw Failure.schedulingFailed }
        }
        tail = next
        try await next.value
    }

    private static func owns(_ id: String) -> Bool { id.hasPrefix("study.") || id.hasPrefix("focus.") }
}
