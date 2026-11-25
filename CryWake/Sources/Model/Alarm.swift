import Foundation

/// Calendar weekday, using the same numbering as `Calendar.component(.weekday, ...)` (1 = Sunday).
enum Weekday: Int, Codable, CaseIterable, Identifiable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

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

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A single alarm. Every field the alarm editor exposes lives here so an alarm round-trips
/// through JSON persistence unchanged.
struct Alarm: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var hour: Int = 7
    var minute: Int = 0
    var label: String = ""
    var repeatDays: Set<Weekday> = []
    var isEnabled: Bool = true

    // Sound
    var voiceID: String = BabyVoice.defaultVoiceID
    var volume: Double = 1.0
    /// Fade the crying in over `fadeInSeconds` instead of starting at full volume.
    var gradualVolume: Bool = true
    var fadeInSeconds: Double = 30
    var vibrate: Bool = true

    // Snooze
    /// Snooze length in minutes. `0` disables snoozing.
    var snoozeMinutes: Int = 5
    /// Maximum number of snoozes. `nil` means unlimited.
    var maxSnoozes: Int? = 3

    // Mission required to turn the alarm off
    var mission: MissionKind = .none
    var missionDifficulty: MissionDifficulty = .normal
    var missionRounds: Int = 1

    // Wake-up check: after dismissal the user has to confirm they are awake,
    // otherwise the baby starts crying again.
    var wakeUpCheck: Bool = false
    var wakeUpCheckMinutes: Int = 3

    var isRepeating: Bool { !repeatDays.isEmpty }

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var displayLabel: String { label.isEmpty ? "Alarm" : label }

    var repeatText: String {
        if repeatDays.isEmpty { return "Once" }
        if repeatDays.count == 7 { return "Every day" }
        if repeatDays == Weekday.weekdays { return "Weekdays" }
        if repeatDays == Weekday.weekend { return "Weekends" }
        return repeatDays.sorted().map(\.shortName).joined(separator: " ")
    }

    func canSnooze(afterSnoozes count: Int) -> Bool {
        guard snoozeMinutes > 0 else { return false }
        guard let maxSnoozes else { return true }
        return count < maxSnoozes
    }

    /// The first moment strictly after `date` at which this alarm should ring,
    /// ignoring `isEnabled`.
    func nextFireDate(after date: Date, calendar: Calendar = .current) -> Date? {
        if repeatDays.isEmpty {
            let comps = DateComponents(hour: hour, minute: minute, second: 0)
            return calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
        }
        return repeatDays.compactMap { day -> Date? in
            let comps = DateComponents(hour: hour, minute: minute, second: 0, weekday: day.rawValue)
            return calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
        }.min()
    }
}

extension Alarm {
    /// Shared encoder/decoder settings for persistence.
    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
