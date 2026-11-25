import Foundation
import UserNotifications

/// Notification scheduling: crying-baby alarm chains (when AlarmKit is unavailable),
/// wake-up checks, bedtime reminders and the "don't close the app" warning.
final class NotificationService {
    static let alarmCategory = "CRADLE_ALARM"
    static let wakeCheckCategory = "CRADLE_WAKE_CHECK"
    static let confirmAwakeAction = "CONFIRM_AWAKE"
    static let alarmPrefix = "alarm."
    static let followUpPrefix = "followup."
    static let wakeCheckPromptID = "wakecheck.prompt"
    static let bedtimeID = "bedtime.reminder"

    private let center = UNUserNotificationCenter.current()

    func registerCategories() {
        let alarm = UNNotificationCategory(identifier: Self.alarmCategory, actions: [],
                                           intentIdentifiers: [], options: [.customDismissAction])
        let confirm = UNNotificationAction(identifier: Self.confirmAwakeAction, title: "I'm awake",
                                           options: [.foreground])
        let check = UNNotificationCategory(identifier: Self.wakeCheckCategory, actions: [confirm],
                                           intentIdentifiers: [], options: [.customDismissAction])
        center.setNotificationCategories([alarm, check])
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Replaces all scheduled alarm chains. Each upcoming occurrence gets a first ring plus
    /// backups so the baby keeps crying if the app was closed.
    func scheduleAlarmChains(alarms: [WakeAlarm], soundFile: (WakeAlarm) -> String,
                             antiCheat: AntiCheatSettings, now: Date = Date()) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier)
            .filter { $0.hasPrefix(Self.alarmPrefix) })

        let occurrences: [(WakeAlarm, Date)] = alarms.flatMap { alarm in
            AlarmSchedule.upcomingFireDates(for: alarm, after: now, count: 2).map { (alarm, $0) }
        }
        let reserved = pending.filter { !$0.identifier.hasPrefix(Self.alarmPrefix) }.count + 4
        let perOccurrence = BackupRingPlan.perOccurrenceBudget(
            alarmOccurrences: occurrences.count, reserved: reserved,
            requested: antiCheat.backupRingCount + 1)
        for (alarm, date) in occurrences {
            let dates = BackupRingPlan.dates(startingAt: date, count: perOccurrence,
                                             spacing: antiCheat.backupRingSpacing)
            for (index, fire) in dates.enumerated() {
                let id = "\(Self.alarmPrefix)\(alarm.id.uuidString).\(Int(date.timeIntervalSince1970)).\(index)"
                await add(id: id, alarm: alarm, fireAt: fire, scheduledAt: date,
                          sound: soundFile(alarm), isBackup: index > 0)
            }
        }
    }

    /// A one-off chain (snooze, wake-up check failure, anti-cheat).
    func scheduleFollowUp(alarm: WakeAlarm, tag: String, at date: Date, sound: String,
                          count: Int, spacing: Int) async {
        cancelFollowUp(tag: tag)
        for (index, fire) in BackupRingPlan.dates(startingAt: date, count: count, spacing: spacing).enumerated() {
            await add(id: "\(Self.followUpPrefix)\(tag).\(index)", alarm: alarm, fireAt: fire,
                      scheduledAt: date, sound: sound, isBackup: index > 0, tag: tag)
        }
    }

    func cancelFollowUp(tag: String) {
        let ids = (0..<64).map { "\(Self.followUpPrefix)\(tag).\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Stops the rest of a ringing occurrence's chain once the mission is done.
    func cancelChain(alarmID: UUID, scheduledAt: Date) async {
        let prefix = "\(Self.alarmPrefix)\(alarmID.uuidString).\(Int(scheduledAt.timeIntervalSince1970))."
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
            .filter { $0.hasPrefix(Self.alarmPrefix) || $0.hasPrefix(Self.followUpPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }

    func scheduleWakeUpCheckPrompt(_ plan: WakeUpCheckPlan, label: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Are you still awake?"
        content.body = "Tap to confirm within \(Int(plan.deadline.timeIntervalSince(plan.promptAt))) seconds, "
            + "or \(label.isEmpty ? "your baby" : label) starts crying again."
        content.sound = .default
        content.categoryIdentifier = Self.wakeCheckCategory
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["alarmID": plan.alarmID.uuidString]
        await addRequest(id: Self.wakeCheckPromptID, content: content, at: plan.promptAt)
    }

    func cancelWakeUpCheckPrompt() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.wakeCheckPromptID])
        center.removeDeliveredNotifications(withIdentifiers: [Self.wakeCheckPromptID])
    }

    func scheduleBedtimeReminder(settings: AppSettings) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.bedtimeID])
        guard settings.bedtimeReminderEnabled else { return }
        let total = settings.bedtimeHour * 60 + settings.bedtimeMinute - settings.bedtimeReminderLeadMinutes
        let minutes = (total % (24 * 60) + 24 * 60) % (24 * 60)
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let content = UNMutableNotificationContent()
        content.title = "Bedtime soon"
        content.body = "Wind down now to get your \(Int(settings.sleepGoalHours)) hours before the baby cries."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: Self.bedtimeID, content: content, trigger: trigger))
    }

    /// Anti-cheat warning when the app is force-quit while an alarm is set.
    func warnAppClosed() {
        let content = UNMutableNotificationContent()
        content.title = "CradleCall was closed"
        content.body = "Your baby will still cry at alarm time, but open the app so it can ring at full volume."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: "app.closed", content: content, trigger: trigger),
                   withCompletionHandler: nil)
    }

    private func add(id: String, alarm: WakeAlarm, fireAt: Date, scheduledAt: Date, sound: String,
                     isBackup: Bool, tag: String? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Your baby is crying" : alarm.label
        content.body = isBackup
            ? "Still crying! Open CradleCall and finish your mission to soothe the baby."
            : "Your baby is crying. Open CradleCall to start your wake-up mission."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        content.categoryIdentifier = Self.alarmCategory
        content.interruptionLevel = .timeSensitive
        var info: [String: Any] = [
            "alarmID": alarm.id.uuidString,
            "scheduledAt": scheduledAt.timeIntervalSince1970,
        ]
        if let tag { info["tag"] = tag }
        content.userInfo = info
        await addRequest(id: id, content: content, at: fireAt)
    }

    private func addRequest(id: String, content: UNNotificationContent, at date: Date) async {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                         from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
