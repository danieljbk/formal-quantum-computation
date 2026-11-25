import Foundation

/// Stores the engine state (alarms, snoozes, wake-up checks) as JSON in UserDefaults.
struct AlarmRepository {
    let defaults: UserDefaults
    var key = "babyalarm.engineState.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> EngineState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(EngineState.self, from: data)
    }

    func save(_ state: EngineState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        if let data = try? encoder.encode(state) {
            defaults.set(data, forKey: key)
        }
    }

    /// First-launch content: a weekday morning alarm, off until the user turns it on.
    static func starterState(now: Date) -> EngineState {
        var morning = Alarm()
        morning.hour = 7
        morning.minute = 0
        morning.label = "Good morning"
        morning.repeatDays = Weekday.weekdays
        morning.isEnabled = false
        var state = EngineState()
        state.alarms = [morning]
        state.lastTick = now
        return state
    }
}

/// Provenance record for one bundled clip (see Resources/Sounds/sounds.json).
struct SoundSource: Codable, Equatable, Identifiable {
    let id: String
    let file: String
    let title: String
    let author: String
    let license: String
    let licenseURL: String
    let sourcePage: String
    let sourceFile: String
    let sourceSHA1: String
    let sha256: String
}

struct SoundManifest: Codable, Equatable {
    let note: String
    let sounds: [SoundSource]

    static func load(from bundle: Bundle) -> SoundManifest? {
        guard let url = bundle.url(forResource: "sounds", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SoundManifest.self, from: data)
    }

    func source(for voiceID: String) -> SoundSource? {
        sounds.first { $0.id == voiceID }
    }
}
