import Foundation

/// Days of the week, numbered like `Calendar.component(.weekday, ...)` (Sunday = 1).
enum Weekday: Int, Codable, CaseIterable, Identifiable, Comparable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var initial: String { String(shortName.prefix(1)) }

    static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<Weekday> = [.saturday, .sunday]
}

/// Ringing volume and how it builds up.
struct SoundSettings: Codable, Hashable {
    /// Target playback volume, 0...1.
    var volume: Double = 1.0
    /// Start quietly and ramp up to `volume`.
    var gradualIncrease: Bool = true
    /// Seconds taken to reach the target volume when `gradualIncrease` is on.
    var rampSeconds: Double = 45
    var vibrate: Bool = true
}

struct SnoozeSettings: Codable, Hashable {
    var isEnabled: Bool = true
    var minutes: Int = 5
    /// Maximum snoozes per ring; `0` means unlimited.
    var maxCount: Int = 3
}

/// After dismissal, ask the sleeper to confirm they are still awake.
struct WakeUpCheckSettings: Codable, Hashable {
    var isEnabled: Bool = true
    /// Minutes after dismissal before the check appears.
    var delayMinutes: Int = 5
    /// Seconds the sleeper has to confirm before the baby starts crying again.
    var responseSeconds: Int = 100
}

/// A scheduled wake-up alarm.
struct WakeAlarm: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var hour: Int
    var minute: Int
    var label: String = "Wake up"
    var repeatDays: Set<Weekday> = []
    var isEnabled: Bool = true
    var voiceID: String = BabyVoice.defaultID
    var missions: [MissionConfig] = [MissionConfig(kind: .math)]
    var sound: SoundSettings = SoundSettings()
    var snooze: SnoozeSettings = SnoozeSettings()
    var wakeUpCheck: WakeUpCheckSettings = WakeUpCheckSettings()
    var showsBriefing: Bool = true
    /// A single occurrence the user chose to skip.
    var skippedOccurrence: Date?
    /// Rings once at this date instead of following `hour`/`minute` (quick alarms).
    var oneShotDate: Date?

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    var isRepeating: Bool { !repeatDays.isEmpty }

    var timeText: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    var repeatSummary: String {
        if oneShotDate != nil { return "Quick alarm" }
        if repeatDays.isEmpty { return "Once" }
        if repeatDays.count == 7 { return "Every day" }
        if repeatDays == Weekday.weekdays { return "Weekdays" }
        if repeatDays == Weekday.weekend { return "Weekends" }
        return repeatDays.sorted().map(\.shortName).joined(separator: " ")
    }
}
