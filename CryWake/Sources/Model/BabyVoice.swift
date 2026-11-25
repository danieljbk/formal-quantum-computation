import Foundation

/// A recorded baby voice the user can pick as their alarm sound.
///
/// The catalog is loaded from `voices.json`, which is written by `tools/fetch_cry_voices.py`
/// alongside the `.caf` files, so the list in the app is always the list of files that were
/// actually fetched, license-checked and encoded.
struct BabyVoice: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let subtitle: String
    let file: String
    let author: String
    let sourcePage: String
    let license: String
    let licenseURL: String

    enum CodingKeys: String, CodingKey {
        case id, name, subtitle, file, author, license
        case sourcePage = "source_page"
        case licenseURL = "license_url"
    }

    var fileStem: String { (file as NSString).deletingPathExtension }
    var fileExtension: String { (file as NSString).pathExtension }

    func url(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: fileStem, withExtension: fileExtension)
    }

    var creditLine: String { "\u{201C}\(name)\u{201D} by \(author), \(license)" }

    static let defaultVoiceID = "newborn_girl"

    private struct CatalogFile: Decodable { let voices: [BabyVoice] }

    static func loadCatalog(from bundle: Bundle) -> [BabyVoice] {
        guard let url = bundle.url(forResource: "voices", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CatalogFile.self, from: data) else {
            return []
        }
        return file.voices
    }

    static let catalog: [BabyVoice] = loadCatalog(from: .main)

    /// Resolves a stored voice id, falling back to the default (or first) voice if the id is unknown.
    static func voice(id: String, in catalog: [BabyVoice] = BabyVoice.catalog) -> BabyVoice? {
        catalog.first { $0.id == id }
            ?? catalog.first { $0.id == defaultVoiceID }
            ?? catalog.first
    }
}
