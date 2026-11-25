import Foundation
import UserNotifications

/// Owns UNUserNotificationCenter: categories, authorization, applying the
/// planner's output, and routing taps / snooze actions back to the engine.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    static let categoryWithSnooze = "BABY_ALARM_SNOOZE"
    static let categoryNoSnooze = "BABY_ALARM"
    static let snoozeAction = "SNOOZE"
    static let openAction = "OPEN"

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    /// Events that arrive before the engine exists (e.g. launch from a notification tap).
    private var queued: [(identifier: String, snooze: Bool)] = []
    weak var engine: AlarmEngine? {
        didSet { flushQueue() }
    }

    func install() {
        center.delegate = self
        let open = UNNotificationAction(identifier: Self.openAction, title: "Calm the baby", options: [.foreground])
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "Snooze", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryWithSnooze, actions: [open, snooze], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: Self.categoryNoSnooze, actions: [open], intentIdentifiers: [], options: []),
        ])
    }

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    func apply(_ plan: [PlannedNotification], calendar: Calendar = .current) {
        center.removeAllPendingNotificationRequests()
        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: item.soundFile))
            content.categoryIdentifier = item.allowsSnooze ? Self.categoryWithSnooze : Self.categoryNoSnooze
            content.threadIdentifier = item.id.key.string
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: item.id.string, content: content, trigger: trigger))
        }
    }

    func clearDelivered() {
        center.removeAllDeliveredNotifications()
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // In the foreground the app rings by itself, so the banner stays silent.
        let identifier = notification.request.identifier
        DispatchQueue.main.async { self.route(identifier: identifier, snooze: false) }
        completionHandler([])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let action = response.actionIdentifier
        DispatchQueue.main.async {
            if action == Self.snoozeAction {
                self.route(identifier: identifier, snooze: true)
            } else if action != UNNotificationDismissActionIdentifier {
                self.route(identifier: identifier, snooze: false)
            }
            completionHandler()
        }
    }

    private func route(identifier: String, snooze: Bool) {
        guard let engine = engine else {
            queued.append((identifier, snooze))
            return
        }
        if snooze {
            engine.snoozeFromNotification(identifier)
        } else {
            engine.openedFromNotification(identifier)
        }
    }

    private func flushQueue() {
        let items = queued
        queued.removeAll()
        for item in items { route(identifier: item.identifier, snooze: item.snooze) }
    }
}
