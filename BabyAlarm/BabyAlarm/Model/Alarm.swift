import Foundation

/// Raw values match `Calendar.component(.weekday, ...)` (1 = Sunday).
enum Weekday: Int, Codable, CaseIterable, Comparable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Monday-first ordering for display.
    static let displayOrder: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<Weekday> = [.saturday, .sunday]

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
}

struct SnoozeSettings: Codable, Equatable {
    var isEnabled: Bool = true
    var minutes: Int = 5
    /// 0 means unlimited.
    var maxCount: Int = 3

    static let minuteOptions = [1, 3, 5, 10, 15, 20, 30]
    static let countOptions = [1, 2, 3, 5, 10, 0]
}

enum MissionKind: String, Codable, CaseIterable, Identifiable {
    case none, math, shake, typing, tap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Off"
        case .math: return "Math"
        case .shake: return "Shake"
        case .typing: return "Typing"
        case .tap: return "Tap"
        }
    }

    var symbolName: String {
        switch self {
        case .none: return "xmark.circle"
        case .math: return "plus.forwardslash.minus"
        case .shake: return "iphone.radiowaves.left.and.right"
        case .typing: return "keyboard"
        case .tap: return "hand.tap"
        }
    }

    var roundsRange: ClosedRange<Int> {
        switch self {
        case .none: return 0...0
        case .math: return 1...10
        case .shake: return 10...200
        case .typing: return 1...5
        case .tap: return 10...200
        }
    }

    var defaultRounds: Int {
        switch self {
        case .none: return 0
        case .math: return 3
        case .shake: return 30
        case .typing: return 1
        case .tap: return 50
        }
    }

    var roundsStep: Int { (self == .shake || self == .tap) ? 10 : 1 }

    func roundsLabel(_ n: Int) -> String {
        switch self {
        case .none: return ""
        case .math: return "\(n) problem\(n == 1 ? "" : "s")"
        case .shake: return "\(n) shakes"
        case .typing: return "\(n) phrase\(n == 1 ? "" : "s")"
        case .tap: return "\(n) taps"
        }
    }
}

enum MathDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct MissionSettings: Codable, Equatable {
    var kind: MissionKind = .math
    var difficulty: MathDifficulty = .easy
    var rounds: Int = MissionKind.math.defaultRounds

    static let off = MissionSettings(kind: .none, difficulty: .easy, rounds: 0)
}

struct WakeUpCheckSettings: Codable, Equatable {
    var isEnabled: Bool = false
    var delayMinutes: Int = 5
    /// Seconds the user has to confirm before the baby starts crying again.
    var confirmWindowSeconds: Int = 100

    static let delayOptions = [3, 5, 10, 15, 30]
}

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var hour: Int = 7
    var minute: Int = 0
    var label: String = ""
    var isEnabled: Bool = true
    var repeatDays: Set<Weekday> = []
    var voiceID: String = BabyVoiceCatalog.defaultVoice.id
    var snooze: SnoozeSettings = SnoozeSettings()
    var mission: MissionSettings = MissionSettings()
    /// 0...1, relative to the device volume.
    var volume: Double = 1.0
    /// 0 = start at full volume.
    var gradualVolumeSeconds: Int = 30
    var vibrate: Bool = true
    var wakeUpCheck: WakeUpCheckSettings = WakeUpCheckSettings()
    /// Set for one-shot "quick alarms": rings once at exactly this instant.
    var oneShotDate: Date? = nil

    static let gradualOptions = [0, 15, 30, 60, 120]

    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return oneShotDate == nil ? "Alarm" : "Quick alarm"
    }

    var isOneShot: Bool { oneShotDate != nil || repeatDays.isEmpty }
}
