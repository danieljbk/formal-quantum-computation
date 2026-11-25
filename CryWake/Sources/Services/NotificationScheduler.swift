import Foundation
import UserNotifications

/// One local notification that should be pending.
struct NotificationPlan: Equatable {
    let identifier: String
    let alarmID: UUID
    let fireDate: Date
    let soundFile: String
    let title: String
    let body: String
}

/// Decides which local notifications back up the in-app alarm. If iOS kills the app, these
/// still make the baby cry: each ringing time gets a burst of notifications spaced so the
/// (<= 30 s) cry clip repeats for several minutes.
enum NotificationPlanner {
    /// iOS keeps at most 64 pending local notifications per app.
    static let systemLimit = 64
    static let maxBurst = 8
    static let burstSpacing: TimeInterval = 30
    static let identifierPrefix = "crywake."

    static func identifier(alarmID: UUID, index: Int, reason: TriggerReason) -> String {
        "\(identifierPrefix)\(alarmID.uuidString).\(reason.rawValue).\(index)"
    }

    static func alarmID(fromIdentifier identifier: String) -> UUID? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        let rest = identifier.dropFirst(identifierPrefix.count)
        return rest.split(separator: ".").first.flatMap { UUID(uuidString: String($0)) }
    }

    static func plans(triggers: [PendingTrigger], alarms: [Alarm], voices: [BabyVoice],
                      now: Date) -> [NotificationPlan] {
        let upcoming = triggers.filter { $0.date > now }
        guard !upcoming.isEmpty else { return [] }
        let burst = max(1, min(maxBurst, systemLimit / upcoming.count))
        var plans: [NotificationPlan] = []
        for trigger in upcoming {
            guard let alarm = alarms.first(where: { $0.id == trigger.alarmID }),
                  let voice = BabyVoice.voice(id: alarm.voiceID, in: voices) else { continue }
            let body: String
            switch trigger.reason {
            case .scheduled: body = "\(alarm.displayLabel) \u{2014} open Cry Wake to soothe the baby."
            case .snooze: body = "Snooze is over. \(alarm.displayLabel)"
            case .wakeCheck: body = "You didn't confirm you were awake. \(alarm.displayLabel)"
            }
            for i in 0..<burst {
                plans.append(NotificationPlan(
                    identifier: identifier(alarmID: alarm.id, index: i, reason: trigger.reason),
                    alarmID: alarm.id,
                    fireDate: trigger.date.addingTimeInterval(Double(i) * burstSpacing),
                    soundFile: voice.file,
                    title: "\u{1F476} \(voice.name) is crying!",
                    body: body))
            }
        }
        return Array(plans.sorted { $0.fireDate < $1.fireDate }.prefix(systemLimit))
    }
}

/// Applies `NotificationPlan`s to `UNUserNotificationCenter`.
final class NotificationScheduler {
    static let categoryID = "CRYWAKE_ALARM"
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
        let category = UNNotificationCategory(identifier: Self.categoryID, actions: [], intentIdentifiers: [],
                                              options: [.customDismissAction])
        center.setNotificationCategories([category])
    }

    func apply(_ plans: [NotificationPlan], calendar: Calendar = .current) {
        center.removeAllPendingNotificationRequests()
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = UNNotificationSound(named: UNNotificationSoundName(plan.soundFile))
            content.categoryIdentifier = Self.categoryID
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["alarmID": plan.alarmID.uuidString]
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger))
        }
    }

    /// Clears notifications already shown for an alarm (once the user soothed the baby in-app).
    func clearDelivered(alarmID: UUID) {
        center.getDeliveredNotifications { [center] delivered in
            let ids = delivered.map(\.request.identifier)
                .filter { NotificationPlanner.alarmID(fromIdentifier: $0) == alarmID }
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }
}
