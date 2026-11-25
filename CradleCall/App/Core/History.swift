import Foundation

/// One morning's wake-up, recorded when the alarm is dismissed.
struct WakeRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var alarmID: UUID
    var alarmLabel: String
    var voiceID: String
    var scheduledAt: Date
    var ringStartedAt: Date
    var dismissedAt: Date
    var snoozeCount: Int
    var missions: [MissionKind]
    /// Seconds spent completing missions.
    var missionSeconds: Double
    var usedEmergencyExit: Bool = false
    /// `nil` when no wake-up check ran.
    var passedWakeUpCheck: Bool?

    /// Seconds from the scheduled time to dismissal.
    var secondsToWake: Double { max(dismissedAt.timeIntervalSince(scheduledAt), 0) }

    /// Up within five minutes, no snoozes and no emergency exit.
    var isOnTime: Bool { secondsToWake <= 5 * 60 && snoozeCount == 0 && !usedEmergencyExit }
}

struct SleepSession: Identifiable, Codable, Hashable {
    enum Source: String, Codable { case manual, bedtime, alarm }

    var id: UUID = UUID()
    var start: Date
    var end: Date?
    var source: Source = .manual
    /// 1...5 self-rated quality.
    var rating: Int?

    var duration: TimeInterval? { end.map { $0.timeIntervalSince(start) } }
}

struct AppSettings: Codable, Hashable {
    var bedtimeHour: Int = 22
    var bedtimeMinute: Int = 30
    var bedtimeReminderEnabled: Bool = true
    /// Minutes before bedtime that the reminder fires.
    var bedtimeReminderLeadMinutes: Int = 30
    var sleepGoalHours: Double = 8
    var useCelsius: Bool = Locale.current.measurementSystem != .us
    var briefingUsesLocation: Bool = true
    var briefingUsesCalendar: Bool = true
    var antiCheat: AntiCheatSettings = AntiCheatSettings()
    var hasCompletedOnboarding: Bool = false
}

/// Everything the app persists, stored as one JSON document.
struct PersistedState: Codable {
    var alarms: [WakeAlarm] = []
    var customVoices: [BabyVoice] = []
    var history: [WakeRecord] = []
    var sleeps: [SleepSession] = []
    var settings: AppSettings = AppSettings()
    var pendingWakeUpCheck: WakeUpCheckPlan?

    static var sample: PersistedState {
        var state = PersistedState()
        var weekday = WakeAlarm(hour: 7, minute: 0)
        weekday.label = "Work day"
        weekday.repeatDays = Weekday.weekdays
        var weekend = WakeAlarm(hour: 9, minute: 0)
        weekend.label = "Lazy weekend"
        weekend.repeatDays = Weekday.weekend
        weekend.voiceID = "cry_toddler_girl"
        weekend.missions = [MissionConfig(kind: .memory, difficulty: .easy)]
        weekend.isEnabled = false
        state.alarms = [weekday, weekend]
        return state
    }
}
