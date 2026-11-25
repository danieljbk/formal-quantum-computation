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
    case none, math, typing, memory, shake, steps, squat, photo, barcode, tap

    var id: String { rawValue }

    /// Kinds offered when adding a mission (everything except "none").
    static var selectable: [MissionKind] { allCases.filter { $0 != .none } }

    var title: String {
        switch self {
        case .none: return "Off"
        case .math: return "Math"
        case .typing: return "Typing"
        case .memory: return "Memory"
        case .shake: return "Shake"
        case .steps: return "Steps"
        case .squat: return "Squats"
        case .photo: return "Photo"
        case .barcode: return "Barcode / QR"
        case .tap: return "Tap"
        }
    }

    var blurb: String {
        switch self {
        case .none: return "One tap stops the crying."
        case .math: return "Solve arithmetic problems."
        case .typing: return "Type a sentence exactly."
        case .memory: return "Repeat a pattern of lit tiles."
        case .shake: return "Shake the phone hard."
        case .steps: return "Walk a number of steps."
        case .squat: return "Do squats holding the phone."
        case .photo: return "Photograph a place you registered, like the bathroom sink."
        case .barcode: return "Scan a barcode or QR code you registered, like a toothpaste tube."
        case .tap: return "Pat the baby many times."
        }
    }

    var symbolName: String {
        switch self {
        case .none: return "xmark.circle"
        case .math: return "plus.forwardslash.minus"
        case .typing: return "keyboard"
        case .memory: return "square.grid.3x3.fill"
        case .shake: return "iphone.radiowaves.left.and.right"
        case .steps: return "figure.walk"
        case .squat: return "figure.strengthtraining.functional"
        case .photo: return "camera.fill"
        case .barcode: return "barcode.viewfinder"
        case .tap: return "hand.tap"
        }
    }

    var roundsRange: ClosedRange<Int> {
        switch self {
        case .none: return 0...0
        case .math: return 1...10
        case .typing: return 1...5
        case .memory: return 1...5
        case .shake: return 10...200
        case .steps: return 10...200
        case .squat: return 5...50
        case .photo, .barcode: return 1...1
        case .tap: return 10...200
        }
    }

    var defaultRounds: Int {
        switch self {
        case .none: return 0
        case .math: return 3
        case .typing: return 1
        case .memory: return 3
        case .shake: return 30
        case .steps: return 30
        case .squat: return 10
        case .photo, .barcode: return 1
        case .tap: return 50
        }
    }

    var roundsStep: Int {
        switch self {
        case .shake, .steps, .tap: return 10
        case .squat: return 5
        default: return 1
        }
    }

    var usesDifficulty: Bool { self == .math || self == .memory }

    /// Photo and barcode missions need something registered before they can run.
    var needsRegistration: Bool { self == .photo || self == .barcode }

    func roundsLabel(_ n: Int) -> String {
        switch self {
        case .none: return ""
        case .math: return "\(n) problem\(n == 1 ? "" : "s")"
        case .typing: return "\(n) phrase\(n == 1 ? "" : "s")"
        case .memory: return "\(n) round\(n == 1 ? "" : "s")"
        case .shake: return "\(n) shakes"
        case .steps: return "\(n) steps"
        case .squat: return "\(n) squats"
        case .photo: return "1 matching photo"
        case .barcode: return "1 matching scan"
        case .tap: return "\(n) taps"
        }
    }
}

enum MathDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct MissionSettings: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var kind: MissionKind = .math
    var difficulty: MathDifficulty = .easy
    var rounds: Int = MissionKind.math.defaultRounds
    /// Barcode mission: the payload registered by the user.
    var barcodePayload: String? = nil
    /// Photo mission: file name of the registered reference photo (app support directory).
    var photoFile: String? = nil

    static let off = MissionSettings(kind: .none, difficulty: .easy, rounds: 0)

    init(kind: MissionKind = .math, difficulty: MathDifficulty = .easy, rounds: Int? = nil,
         barcodePayload: String? = nil, photoFile: String? = nil) {
        self.kind = kind
        self.difficulty = difficulty
        self.rounds = rounds ?? kind.defaultRounds
        self.barcodePayload = barcodePayload
        self.photoFile = photoFile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(MissionKind.self, forKey: .kind) ?? .math
        difficulty = try c.decodeIfPresent(MathDifficulty.self, forKey: .difficulty) ?? .easy
        rounds = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? kind.defaultRounds
        barcodePayload = try c.decodeIfPresent(String.self, forKey: .barcodePayload)
        photoFile = try c.decodeIfPresent(String.self, forKey: .photoFile)
    }

    /// False for photo / barcode missions that were never registered.
    var isReady: Bool {
        switch kind {
        case .photo: return photoFile != nil
        case .barcode: return !(barcodePayload ?? "").isEmpty
        default: return true
        }
    }

    var summary: String {
        kind == .none ? "Off" : "\(kind.title) · \(kind.roundsLabel(rounds))"
    }
}

struct WakeUpCheckSettings: Codable, Equatable {
    var isEnabled: Bool = false
    var delayMinutes: Int = 5
    /// Seconds the user has to confirm before the baby starts crying again.
    var confirmWindowSeconds: Int = 100

    static let delayOptions = [3, 5, 10, 15, 30]
}

struct Alarm: Identifiable, Codable, Equatable {
    static let maxMissions = 5

    var id: UUID = UUID()
    var hour: Int = 7
    var minute: Int = 0
    var label: String = ""
    var isEnabled: Bool = true
    var repeatDays: Set<Weekday> = []
    var voiceID: String = BabyVoiceCatalog.defaultVoice.id
    var snooze: SnoozeSettings = SnoozeSettings()
    /// Missions run one after another; the crying stops after the last one.
    var missions: [MissionSettings] = [MissionSettings()]
    /// 0...1, relative to the device volume.
    var volume: Double = 1.0
    /// 0 = start at full volume.
    var gradualVolumeSeconds: Int = 30
    /// Move through fussier babies the longer the alarm rings.
    var cryEscalation: Bool = true
    var vibrate: Bool = true
    var wakeUpCheck: WakeUpCheckSettings = WakeUpCheckSettings()
    /// Set for one-shot "quick alarms": rings once at exactly this instant.
    var oneShotDate: Date? = nil
    /// A single upcoming occurrence the user chose to skip.
    var skippedOccurrence: Date? = nil

    static let gradualOptions = [0, 15, 30, 60, 120]

    init() {}

    /// The missions that will actually run (unregistered photo/barcode missions are skipped).
    var activeMissions: [MissionSettings] {
        missions.filter { $0.kind != .none && $0.isReady }
    }

    var missionSummary: String {
        let active = activeMissions
        if active.isEmpty { return "No mission" }
        return active.map(\.kind.title).joined(separator: " → ")
    }

    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return oneShotDate == nil ? "Alarm" : "Quick alarm"
    }

    var isOneShot: Bool { oneShotDate != nil || repeatDays.isEmpty }

    /// A copy with a fresh identity, for "Duplicate".
    func duplicated() -> Alarm {
        var copy = self
        copy.id = UUID()
        copy.skippedOccurrence = nil
        copy.missions = missions.map { var m = $0; m.id = UUID(); return m }
        return copy
    }

    // MARK: Codable (tolerant of older saved data)

    private enum CodingKeys: String, CodingKey {
        case id, hour, minute, label, isEnabled, repeatDays, voiceID, snooze, missions, mission
        case volume, gradualVolumeSeconds, cryEscalation, vibrate, wakeUpCheck, oneShotDate, skippedOccurrence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 7
        minute = try c.decodeIfPresent(Int.self, forKey: .minute) ?? 0
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        repeatDays = try c.decodeIfPresent(Set<Weekday>.self, forKey: .repeatDays) ?? []
        voiceID = try c.decodeIfPresent(String.self, forKey: .voiceID) ?? BabyVoiceCatalog.defaultVoice.id
        snooze = try c.decodeIfPresent(SnoozeSettings.self, forKey: .snooze) ?? SnoozeSettings()
        if let list = try c.decodeIfPresent([MissionSettings].self, forKey: .missions) {
            missions = list
        } else if let single = try c.decodeIfPresent(MissionSettings.self, forKey: .mission) {
            missions = single.kind == .none ? [] : [single]
        } else {
            missions = [MissionSettings()]
        }
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 1.0
        gradualVolumeSeconds = try c.decodeIfPresent(Int.self, forKey: .gradualVolumeSeconds) ?? 30
        cryEscalation = try c.decodeIfPresent(Bool.self, forKey: .cryEscalation) ?? true
        vibrate = try c.decodeIfPresent(Bool.self, forKey: .vibrate) ?? true
        wakeUpCheck = try c.decodeIfPresent(WakeUpCheckSettings.self, forKey: .wakeUpCheck) ?? WakeUpCheckSettings()
        oneShotDate = try c.decodeIfPresent(Date.self, forKey: .oneShotDate)
        skippedOccurrence = try c.decodeIfPresent(Date.self, forKey: .skippedOccurrence)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(hour, forKey: .hour)
        try c.encode(minute, forKey: .minute)
        try c.encode(label, forKey: .label)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encode(repeatDays, forKey: .repeatDays)
        try c.encode(voiceID, forKey: .voiceID)
        try c.encode(snooze, forKey: .snooze)
        try c.encode(missions, forKey: .missions)
        try c.encode(volume, forKey: .volume)
        try c.encode(gradualVolumeSeconds, forKey: .gradualVolumeSeconds)
        try c.encode(cryEscalation, forKey: .cryEscalation)
        try c.encode(vibrate, forKey: .vibrate)
        try c.encode(wakeUpCheck, forKey: .wakeUpCheck)
        try c.encodeIfPresent(oneShotDate, forKey: .oneShotDate)
        try c.encodeIfPresent(skippedOccurrence, forKey: .skippedOccurrence)
    }
}
