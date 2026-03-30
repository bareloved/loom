import Foundation
import UserNotifications

@Observable
@MainActor
final class ReminderManager: NSObject, UNUserNotificationCenterDelegate {
    private(set) var isAuthorized: Bool = false
    var onStartSession: (() -> Void)?
    var isSessionActive: (() -> Bool)?

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        registerCategory()
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        center.getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            isAuthorized = granted
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            isAuthorized = false
            return false
        }
    }

    // MARK: - Category Registration

    private func registerCategory() {
        let startAction = UNNotificationAction(
            identifier: "START_SESSION",
            title: "Start Session",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "SESSION_REMINDER",
            actions: [startAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Scheduling

    func rescheduleAll(hour: Int, minute: Int, days: Set<Int>) {
        center.removeAllPendingNotificationRequests()

        for weekday in days {
            let content = UNMutableNotificationContent()
            content.title = "Time to focus"
            content.body = "Start a session to begin tracking your work"
            content.sound = .default
            content.categoryIdentifier = "SESSION_REMINDER"

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "loom-reminder-\(weekday)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("Failed to schedule reminder for weekday \(weekday): \(error)")
                }
            }
        }
    }

    func removeAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Idle Stop Notification

    func notifySessionStoppedDueToIdle(category: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Session stopped"
        content.body = "Your \(category) session was stopped due to inactivity"
        content.sound = .default
        content.categoryIdentifier = "SESSION_REMINDER"

        let request = UNNotificationRequest(
            identifier: "loom-idle-stop-\(UUID().uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )

        center.add(request) { error in
            if let error {
                print("Failed to send idle stop notification: \(error)")
            }
        }
    }

    func notifySessionStoppedDueToSleep(category: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Session stopped"
        content.body = "Your \(category) session was stopped — Mac went to sleep"
        content.sound = .default
        content.categoryIdentifier = "SESSION_REMINDER"

        let request = UNNotificationRequest(
            identifier: "loom-sleep-stop-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Failed to send sleep stop notification: \(error)")
            }
        }
    }

    func notifyCalendarWriteFailed() {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Session not saved"
        content.body = "Couldn't save your session to calendar"
        content.sound = .default
        content.categoryIdentifier = "SESSION_REMINDER"

        let request = UNNotificationRequest(
            identifier: "loom-cal-fail-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Failed to send calendar failure notification: \(error)")
            }
        }
    }

    func notifySyncFailed() {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Sync issue"
        content.body = "Couldn't sync your session — check your connection"
        content.categoryIdentifier = "SESSION_REMINDER"

        let request = UNNotificationRequest(
            identifier: "loom-sync-fail-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Failed to send sync failure notification: \(error)")
            }
        }
    }

    func notifyRemoteSessionStarted(category: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tracking from another device"
        content.body = "A \(category) session started from iPhone — now tracking on Mac"
        content.categoryIdentifier = "SESSION_REMINDER"

        let request = UNNotificationRequest(
            identifier: "loom-remote-start-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Failed to send remote session notification: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let isActive = MainActor.assumeIsolated {
            self.isSessionActive?() == true
        }
        if isActive {
            completionHandler([])
        } else {
            completionHandler([.banner, .sound])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        if actionId == UNNotificationDefaultActionIdentifier || actionId == "START_SESSION" {
            MainActor.assumeIsolated {
                self.onStartSession?()
            }
        }
        completionHandler()
    }
}
