import Foundation
import UserNotifications

public final class NotificationManager {
    public static let shared = NotificationManager()

    /// Only attempt UserNotifications if running inside a true .app bundle and not inside XCTest
    private var isSupported: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        guard let id = Bundle.main.bundleIdentifier, !id.isEmpty else { return false }
        return Bundle.main.bundleURL.pathExtension == "app"
    }

    private var center: UNUserNotificationCenter? {
        guard isSupported else { return nil }
        return UNUserNotificationCenter.current()
    }

    private init() {}

    public func requestAuthorization() {
        guard let center = center else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[doto] Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    public func scheduleNotifications(for task: TaskItem) {
        // Cancel existing first to prevent duplicates
        cancelNotifications(for: task.id)

        guard let center = center, !task.isCompleted, let deadline = task.deadlineDate else { return }

        // Trigger milestones relative to deadline (23:59:59 of due date)
        let milestones: [(identifier: String, hoursBefore: Double, message: String)] = [
            ("24h", 24.0, "\"\(task.title)\" is due in 1 day."),
            ("12h", 12.0, "\"\(task.title)\" is due in 12 hours."),
            ("6h", 6.0, "\"\(task.title)\" is due in 6 hours.")
        ]

        let now = Date()

        for milestone in milestones {
            let triggerDate = deadline.addingTimeInterval(-milestone.hoursBefore * 3600)
            let remainingSeconds = triggerDate.timeIntervalSince(now)

            // Only schedule if the trigger time is in the future
            if remainingSeconds > 5 {
                let content = UNMutableNotificationContent()
                content.title = "doto"
                content.body = milestone.message
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingSeconds, repeats: false)
                let reqId = "\(task.id.uuidString)_\(milestone.identifier)"
                let request = UNNotificationRequest(identifier: reqId, content: content, trigger: trigger)

                center.add(request) { error in
                    if let error = error {
                        print("[doto] Failed to schedule notification: \(error)")
                    }
                }
            }
        }
    }

    public func cancelNotifications(for taskId: UUID) {
        guard let center = center else { return }
        let identifiers = [
            "\(taskId.uuidString)_24h",
            "\(taskId.uuidString)_12h",
            "\(taskId.uuidString)_6h"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    public func removeAll() {
        guard let center = center else { return }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
