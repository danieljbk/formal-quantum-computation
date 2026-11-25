import Foundation

/// A real recorded baby cry that can be used as an alarm sound.
struct BabyVoice: Identifiable, Codable, Hashable {
    enum Origin: String, Codable {
        /// Bundled with the app, from the Donate-a-cry corpus.
        case bundled
        /// Recorded by the user with the microphone (e.g. their own baby).
        case recorded
        /// Imported by the user from Files.
        case imported
    }

    var id: String
    var name: String
    var detail: String
    var origin: Origin
    /// File name, with extension. Bundled voices live in the app bundle; custom voices in
    /// `Library/Sounds`, where notifications and AlarmKit can also find them.
    var fileName: String

    var isCustom: Bool { origin != .bundled }

    static let defaultID = "cry_newborn_girl"

    /// Every bundled voice is a genuine infant recording; see CREDITS.md.
    static let bundled: [BabyVoice] = [
        BabyVoice(id: "cry_newborn_girl", name: "Newborn girl",
                  detail: "0–4 weeks · hungry", origin: .bundled, fileName: "cry_newborn_girl.caf"),
        BabyVoice(id: "cry_newborn_boy", name: "Newborn boy",
                  detail: "0–4 weeks · hungry", origin: .bundled, fileName: "cry_newborn_boy.caf"),
        BabyVoice(id: "cry_hungry_girl", name: "Hungry little girl",
                  detail: "2–6 months · hungry", origin: .bundled, fileName: "cry_hungry_girl.caf"),
        BabyVoice(id: "cry_fussy_girl", name: "Fussy little girl",
                  detail: "1–6 months · discomfort", origin: .bundled, fileName: "cry_fussy_girl.caf"),
        BabyVoice(id: "cry_baby_boy", name: "Baby boy",
                  detail: "2–6 months · hungry", origin: .bundled, fileName: "cry_baby_boy.caf"),
        BabyVoice(id: "cry_toddler_boy", name: "Toddler boy",
                  detail: "7 months–2 years · upset", origin: .bundled, fileName: "cry_toddler_boy.caf"),
        BabyVoice(id: "cry_toddler_girl", name: "Toddler girl",
                  detail: "2 years+ · upset", origin: .bundled, fileName: "cry_toddler_girl.caf"),
    ]

    /// Longest sound iOS will play for a notification; custom recordings are trimmed to fit.
    static let maximumNotificationSeconds: Double = 29
}
