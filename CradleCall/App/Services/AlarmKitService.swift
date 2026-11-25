import Foundation

#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI

/// Metadata attached to every system alarm CradleCall schedules.
@available(iOS 26.0, *)
struct CradleAlarmMetadata: AlarmMetadata {
    var alarmID: String
}

/// Schedules CradleCall alarms with AlarmKit (iOS 26+), so the crying baby breaks through
/// Silent mode and Focus, and rings even if the app has been closed.
@available(iOS 26.0, *)
enum AlarmKitService {
    static var manager: AlarmManager { AlarmManager.shared }

    static var isAuthorized: Bool { manager.authorizationState == .authorized }

    static func requestAuthorization() async -> Bool {
        switch manager.authorizationState {
        case .authorized: return true
        case .denied: return false
        default:
            do { return try await manager.requestAuthorization() == .authorized } catch { return false }
        }
    }

    /// Replaces every scheduled system alarm with the enabled `alarms`.
    static func sync(alarms: [WakeAlarm], soundFile: (WakeAlarm) -> String) async {
        let existing = (try? manager.alarms) ?? []
        let follow = FollowUpRegistry.allIDs
        for alarm in existing where !follow.contains(alarm.id) {
            try? manager.cancel(id: alarm.id)
        }
        for alarm in alarms where alarm.isEnabled {
            guard let alarmSchedule = systemSchedule(for: alarm) else { continue }
            await schedule(alarm: alarm, id: alarm.id, schedule: alarmSchedule, sound: soundFile(alarm))
        }
    }

    /// A one-off ring at `date` (snoozes, wake-up check failures, anti-cheat re-rings).
    static func scheduleFollowUp(alarm: WakeAlarm, tag: String, at date: Date, sound: String) async {
        let id = FollowUpRegistry.id(for: tag, alarmID: alarm.id)
        try? manager.cancel(id: id)
        await schedule(alarm: alarm, id: id, schedule: .fixed(date), sound: sound)
    }

    static func cancelFollowUp(tag: String) {
        guard let id = FollowUpRegistry.existingID(for: tag) else { return }
        try? manager.cancel(id: id)
        FollowUpRegistry.remove(tag: tag)
    }

    /// Silences a ringing system alarm once the app has taken over the crying.
    static func stopAlerting() {
        for alarm in (try? manager.alarms) ?? [] where alarm.state == .alerting {
            try? manager.stop(id: alarm.id)
        }
    }

    /// Calls `onAlert` with the CradleCall alarm id whenever a system alarm starts ringing.
    static func observeAlerts(_ onAlert: @escaping @MainActor (UUID) -> Void) -> Task<Void, Never> {
        Task {
            for await alarms in manager.alarmUpdates {
                for alarm in alarms where alarm.state == .alerting {
                    let owner = FollowUpRegistry.alarmID(forSystemID: alarm.id) ?? alarm.id
                    await onAlert(owner)
                }
            }
        }
    }

    private static func systemSchedule(for alarm: WakeAlarm) -> AlarmKit.Alarm.Schedule? {
        if let oneShot = alarm.oneShotDate {
            return oneShot > Date() ? .fixed(oneShot) : nil
        }
        if let skipped = alarm.skippedOccurrence, skipped > Date(),
           let next = AlarmSchedule.nextFireDate(for: alarm, after: Date()) {
            // AlarmKit cannot skip a single weekly occurrence, so ring once at the next
            // unskipped time; the following sync restores the weekly schedule.
            return .fixed(next)
        }
        let time = AlarmKit.Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
        let recurrence: AlarmKit.Alarm.Schedule.Relative.Recurrence = alarm.repeatDays.isEmpty
            ? .never
            : .weekly(alarm.repeatDays.sorted().map(\.localeWeekday))
        return .relative(.init(time: time, repeats: recurrence))
    }

    private static func schedule(alarm: WakeAlarm, id: UUID, schedule: AlarmKit.Alarm.Schedule,
                                 sound: String) async {
        let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        let mission = AlarmButton(text: "Soothe baby", textColor: .white, systemImageName: "figure.walk")
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.label.isEmpty ? "Your baby is crying" : alarm.label),
            stopButton: stop,
            secondaryButton: mission,
            secondaryButtonBehavior: .custom)
        let attributes = AlarmAttributes<CradleAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: CradleAlarmMetadata(alarmID: alarm.id.uuidString),
            tintColor: Color.pink)
        let configuration = AlarmManager.AlarmConfiguration<CradleAlarmMetadata>(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopCryingIntent(alarmID: alarm.id.uuidString),
            secondaryIntent: StartMissionIntent(alarmID: alarm.id.uuidString),
            sound: .named(sound))
        _ = try? await manager.schedule(id: id, configuration: configuration)
    }
}

private extension Weekday {
    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday: return .sunday
        case .monday: return .monday
        case .tuesday: return .tuesday
        case .wednesday: return .wednesday
        case .thursday: return .thursday
        case .friday: return .friday
        case .saturday: return .saturday
        }
    }
}

/// "Soothe baby": opens CradleCall straight into the wake-up mission.
@available(iOS 26.0, *)
struct StartMissionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start wake-up mission"
    static let openAppWhenRun = true

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() { alarmID = "" }
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        LaunchRouter.requestMission(alarmID: alarmID)
        return .result()
    }
}

/// "Stop" on the system alarm. Stopping without doing the mission is cheating, so the baby
/// starts crying again a minute later until the mission is done in the app.
@available(iOS 26.0, *)
struct StopCryingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop crying"

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() { alarmID = "" }
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmID),
              let alarm = PersistenceController.load().alarms.first(where: { $0.id == uuid }) else {
            return .result()
        }
        let sound = VoiceLibrary.soundFileName(for: alarm.voiceID,
                                               custom: PersistenceController.load().customVoices)
        await AlarmKitService.scheduleFollowUp(alarm: alarm, tag: FollowUpTag.stopped(uuid),
                                               at: Date().addingTimeInterval(60), sound: sound)
        return .result()
    }
}
#endif

/// Tags for one-off follow-up rings.
enum FollowUpTag {
    static func snooze(_ id: UUID) -> String { "snooze-\(id.uuidString)" }
    static func deadman(_ id: UUID) -> String { "deadman-\(id.uuidString)" }
    static func wakeCheck(_ id: UUID) -> String { "wakecheck-\(id.uuidString)" }
    static func stopped(_ id: UUID) -> String { "stopped-\(id.uuidString)" }

    static func all(for id: UUID) -> [String] {
        [snooze(id), deadman(id), wakeCheck(id), stopped(id)]
    }
}

/// Remembers the system alarm ids used for follow-up rings so they can be cancelled.
enum FollowUpRegistry {
    private static let key = "followUpRegistry"
    private static var defaults: UserDefaults { .standard }

    /// tag -> [systemID, alarmID]
    private static var table: [String: [String]] {
        get { defaults.dictionary(forKey: key) as? [String: [String]] ?? [:] }
        set { defaults.set(newValue, forKey: key) }
    }

    static func id(for tag: String, alarmID: UUID) -> UUID {
        if let existing = existingID(for: tag) { return existing }
        let id = UUID()
        table[tag] = [id.uuidString, alarmID.uuidString]
        return id
    }

    static func existingID(for tag: String) -> UUID? {
        table[tag].flatMap { $0.first }.flatMap(UUID.init(uuidString:))
    }

    static func remove(tag: String) { table[tag] = nil }

    static var allIDs: Set<UUID> {
        Set(table.values.compactMap { $0.first.flatMap(UUID.init(uuidString:)) })
    }

    static func alarmID(forSystemID id: UUID) -> UUID? {
        table.values.first { $0.first == id.uuidString }.flatMap { $0.last }.flatMap(UUID.init(uuidString:))
    }
}

/// Hands requests from intents and notifications to the running app.
enum LaunchRouter {
    private static let key = "pendingMissionAlarmID"

    static func requestMission(alarmID: String) {
        UserDefaults.standard.set(alarmID, forKey: key)
        NotificationCenter.default.post(name: .cradleCallMissionRequested, object: nil)
    }

    static func takePendingMission() -> UUID? {
        defer { UserDefaults.standard.removeObject(forKey: key) }
        return UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:))
    }
}

extension Notification.Name {
    static let cradleCallMissionRequested = Notification.Name("cradleCallMissionRequested")
}
