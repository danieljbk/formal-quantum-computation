import Foundation

/// A sound picked up by the microphone during a night (snoring, talking, coughing, ...).
struct SoundEvent: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    /// Seconds from the start of the recording.
    let offset: TimeInterval
    let duration: TimeInterval
    /// Peak level in dBFS (0 = loudest).
    let peakLevel: Double
}

struct SleepSession: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    let start: Date
    var end: Date?
    var soundID: String?
    var events: [SoundEvent] = []
    /// File name of the night's recording in the app's documents directory, if recording was on.
    var recordingFile: String?

    var duration: TimeInterval { (end ?? start).timeIntervalSince(start) }
    var isActive: Bool { end == nil }

    var loudestEvents: [SoundEvent] {
        Array(events.sorted { $0.peakLevel > $1.peakLevel }.prefix(10)).sorted { $0.offset < $1.offset }
    }
}

/// Turns a stream of microphone levels into discrete sound events.
struct SoundEventDetector {
    /// Level (dBFS) above which the room counts as "noisy".
    var threshold: Double = -35
    /// Shorter blips are ignored.
    var minDuration: TimeInterval = 1.0
    /// Quiet gaps shorter than this are bridged (one snore cycle stays one event).
    var mergeGap: TimeInterval = 2.0

    private var openStart: TimeInterval?
    private var openPeak: Double = -160
    private var lastLoud: TimeInterval = 0
    private(set) var events: [SoundEvent] = []

    init(threshold: Double = -35, minDuration: TimeInterval = 1.0, mergeGap: TimeInterval = 2.0) {
        self.threshold = threshold
        self.minDuration = minDuration
        self.mergeGap = mergeGap
    }

    /// Feed one level sample taken `time` seconds into the recording.
    mutating func ingest(level: Double, at time: TimeInterval) {
        if level >= threshold {
            if openStart == nil {
                openStart = time
                openPeak = level
            }
            openPeak = max(openPeak, level)
            lastLoud = time
        } else if let start = openStart, time - lastLoud > mergeGap {
            close(start: start)
        }
    }

    /// Close any event still open at the end of the night.
    mutating func finish() {
        if let start = openStart { close(start: start) }
    }

    private mutating func close(start: TimeInterval) {
        let duration = lastLoud - start
        if duration >= minDuration {
            events.append(SoundEvent(offset: start, duration: duration, peakLevel: openPeak))
        }
        openStart = nil
        openPeak = -160
    }
}

/// Bedtime reminder and sleep-sound preferences.
struct SleepSettings: Codable, Equatable {
    var bedtimeReminderEnabled = false
    var bedtimeHour = 22
    var bedtimeMinute = 30
    /// Minutes the sleep sound plays before fading out; 0 = until stopped.
    var soundTimerMinutes = 30
    var recordSounds = true

    static let timerOptions = [0, 15, 30, 45, 60, 90]
}

struct SleepSound: Identifiable, Hashable {
    let id: String
    let displayName: String
    let emoji: String

    var fileName: String { "\(id).\(Self.fileExtension)" }
    static let fileExtension = "m4a"
}

enum SleepSoundCatalog {
    static let all: [SleepSound] = [
        SleepSound(id: "sleep_rain", displayName: "Rain on the window", emoji: "🌧️"),
        SleepSound(id: "sleep_thunder", displayName: "Distant thunder", emoji: "⛈️"),
        SleepSound(id: "sleep_ocean", displayName: "Ocean waves", emoji: "🌊"),
        SleepSound(id: "sleep_river", displayName: "River rapids", emoji: "🏞️"),
    ]

    static func sound(id: String?) -> SleepSound? {
        all.first { $0.id == id }
    }
}
