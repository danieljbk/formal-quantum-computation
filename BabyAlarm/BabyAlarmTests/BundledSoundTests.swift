#if os(iOS)
import AVFoundation
import CryptoKit
import XCTest
@testable import BabyAlarm

/// Runs inside the host app: checks the clips that actually ship.
final class BundledSoundTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: AlarmEngine.self) }

    private func manifest() throws -> SoundManifest {
        try XCTUnwrap(SoundManifest.load(from: bundle), "sounds.json must be bundled")
    }

    func testManifestCoversEveryVoiceWithProvenance() throws {
        let m = try manifest()
        XCTAssertEqual(Set(m.sounds.map(\.id)), Set(BabyVoiceCatalog.all.map(\.id)))
        for voice in BabyVoiceCatalog.all {
            let s = try XCTUnwrap(m.source(for: voice.id))
            XCTAssertEqual(s.file, voice.fileName)
            XCTAssertTrue(s.sourceFile.hasPrefix("https://upload.wikimedia.org/"), s.sourceFile)
            XCTAssertTrue(s.sourcePage.hasPrefix("https://commons.wikimedia.org/wiki/File:"), s.sourcePage)
            XCTAssertEqual(s.sourceSHA1.count, 40)
            XCTAssertEqual(s.sha256.count, 64)
            XCTAssertFalse(s.license.isEmpty)
            XCTAssertFalse(s.author.isEmpty)
        }
    }

    func testBundledClipsMatchRecordedDigests() throws {
        for s in try manifest().sounds {
            let url = try XCTUnwrap(bundle.url(forResource: s.id, withExtension: BabyVoice.fileExtension), "\(s.file) missing from app bundle")
            let digest = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, s.sha256, s.file)
        }
    }

    func testClipsAreUsableAsNotificationSounds() throws {
        for voice in BabyVoiceCatalog.all {
            let url = try XCTUnwrap(AudioService.url(for: voice, in: bundle))
            let file = try AVAudioFile(forReading: url)
            let seconds = Double(file.length) / file.processingFormat.sampleRate
            XCTAssertGreaterThan(seconds, 10, voice.id)
            XCTAssertLessThanOrEqual(seconds, 30, "iOS ignores notification sounds longer than 30 s (\(voice.id))")
            XCTAssertNoThrow(try AVAudioPlayer(contentsOf: url), voice.id)
        }
    }

    func testPlannedNotificationsReferenceBundledSounds() throws {
        var state = EngineState()
        var alarm = Alarm()
        alarm.repeatDays = Set(Weekday.allCases)
        alarm.voiceID = BabyVoiceCatalog.randomID
        state.alarms = [alarm]
        let plan = NotificationPlanner.plan(core: AlarmEngineCore(state: state), now: Date())
        XCTAssertFalse(plan.isEmpty)
        for item in plan {
            let base = (item.soundFile as NSString).deletingPathExtension
            XCTAssertNotNil(bundle.url(forResource: base, withExtension: BabyVoice.fileExtension), item.soundFile)
        }
    }

    func testHostAppEngineIsInertUnderTests() {
        XCTAssertTrue(AppEnvironment.isRunningTests)
        let engine = AlarmEngine(defaults: UserDefaults(suiteName: "babyalarm.hosttest.\(UUID().uuidString)")!, live: false)
        XCTAssertFalse(engine.alarms.isEmpty, "first launch shows a starter alarm")
        var a = Alarm()
        a.hour = 6
        engine.save(a)
        XCTAssertTrue(engine.alarms.contains { $0.id == a.id })
        engine.applyVoiceToAllAlarms("cry_hungry")
        XCTAssertTrue(engine.alarms.allSatisfy { $0.voiceID == "cry_hungry" })
        engine.delete(id: a.id)
        XCTAssertFalse(engine.alarms.contains { $0.id == a.id })
        XCTAssertNotNil(BabyVoiceCatalog.voice(id: engine.defaultVoiceID))
        engine.defaultVoiceID = BabyVoiceCatalog.randomID
        XCTAssertEqual(engine.defaultVoiceID, BabyVoiceCatalog.randomID)
    }

    func testAppInfoPlistDeclaresBackgroundAudio() {
        let modes = Bundle(for: AlarmEngine.self).object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        XCTAssertEqual(modes, ["audio"])
    }
}
#endif
