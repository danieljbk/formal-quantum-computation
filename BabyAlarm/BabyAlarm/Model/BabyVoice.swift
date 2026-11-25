import Foundation

/// One selectable baby voice. `id` doubles as the base name of the bundled `.caf` clip.
struct BabyVoice: Identifiable, Hashable {
    let id: String
    let displayName: String
    let blurb: String
    let emoji: String

    var fileName: String { id + ".caf" }
}

enum BabyVoiceCatalog {
    /// Sentinel voice id meaning "pick a different baby every day".
    static let randomID = "random"

    static let all: [BabyVoice] = [
        BabyVoice(id: "cry_newborn", displayName: "Newborn", blurb: "A brand-new baby, short urgent wails.", emoji: "👶"),
        BabyVoice(id: "cry_fussy", displayName: "Fussy", blurb: "Disappointed sobbing that builds up.", emoji: "😢"),
        BabyVoice(id: "cry_hungry", displayName: "Hungry", blurb: "A long, wanting cry for breakfast.", emoji: "🍼"),
        BabyVoice(id: "cry_nursery", displayName: "Nursery", blurb: "Real nursery recording, steady crying.", emoji: "🧸"),
    ]

    static var defaultVoice: BabyVoice { all[0] }

    static func voice(id: String) -> BabyVoice? {
        all.first { $0.id == id }
    }

    static func displayName(for voiceID: String) -> String {
        if voiceID == randomID { return "Surprise baby (changes daily)" }
        return voice(id: voiceID)?.displayName ?? defaultVoice.displayName
    }

    /// Resolves a stored voice choice to a concrete voice for a given ring time.
    /// "Random" is deterministic per calendar day so the notification sound and
    /// the in-app sound for the same occurrence always match.
    static func resolve(_ voiceID: String, for date: Date, calendar: Calendar = .current) -> BabyVoice {
        if voiceID == randomID {
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            let seed = (c.year ?? 0) * 372 + (c.month ?? 0) * 31 + (c.day ?? 0)
            return all[((seed % all.count) + all.count) % all.count]
        }
        return voice(id: voiceID) ?? defaultVoice
    }
}
