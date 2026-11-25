import AVFoundation
import XCTest
@testable import CradleCall

/// Checks the bundled baby recordings and the app's wake-up flow.
@MainActor
final class AppBehaviourTests: XCTestCase {
    func testEveryBundledVoiceIsARealPlayableRecording() throws {
        XCTAssertGreaterThanOrEqual(BabyVoice.bundled.count, 4)
        XCTAssertEqual(Set(BabyVoice.bundled.map(\.id)).count, BabyVoice.bundled.count)
        for voice in BabyVoice.bundled {
            let url = VoiceLibrary.url(for: voice)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing \(voice.fileName)")
            let file = try AVAudioFile(forReading: url)
            let seconds = Double(file.length) / file.fileFormat.sampleRate
            XCTAssertGreaterThan(seconds, 10, voice.id)
            // iOS ignores notification sounds longer than 30 s.
            XCTAssertLessThan(seconds, 30, voice.id)
            XCTAssertNotNil(try? AVAudioPlayer(contentsOf: url), voice.id)
        }
    }

    func testBundledVoicesAreTracedToTheirSourceRecordings() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "voice_sources", withExtension: "json"))
        let entries = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]]
        let ids = Set((entries ?? []).compactMap { $0["id"] as? String })
        XCTAssertEqual(ids, Set(BabyVoice.bundled.map(\.id)))
        for entry in entries ?? [] {
            let clips = entry["sourceClips"] as? [String] ?? []
            XCTAssertFalse(clips.isEmpty)
            XCTAssertTrue(clips.allSatisfy { ($0 as NSString).pathExtension == "caf" })
        }
    }

    func testDefaultAlarmUsesABundledBabyVoiceAndAMission() {
        let alarm = WakeAlarm(hour: 7, minute: 0)
        XCTAssertTrue(BabyVoice.bundled.contains { $0.id == alarm.voiceID })
        XCTAssertFalse(alarm.missions.isEmpty)
    }

    func testUnknownVoiceFallsBackToBundledCry() {
        XCTAssertEqual(VoiceLibrary.soundFileName(for: "nope", custom: []), BabyVoice.bundled[0].fileName)
        let missing = BabyVoice(id: "custom-x", name: "Gone", detail: "", origin: .recorded,
                                fileName: "deleted-recording-\(UUID().uuidString)")
        XCTAssertEqual(VoiceLibrary.soundFileName(for: "custom-x", custom: [missing]),
                       BabyVoice.bundled[0].fileName)
    }

    func testStateRoundTripsThroughJSON() throws {
        var state = PersistedState.sample
        state.history.append(WakeRecord(alarmID: UUID(), alarmLabel: "x", voiceID: "cry_baby_boy",
                                        scheduledAt: Date(timeIntervalSince1970: 100),
                                        ringStartedAt: Date(timeIntervalSince1970: 100),
                                        dismissedAt: Date(timeIntervalSince1970: 200), snoozeCount: 1,
                                        missions: [.memory, .steps], missionSeconds: 12))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("state-\(UUID()).json")
        PersistenceController.save(state, to: url)
        let loaded = PersistenceController.load(from: url)
        XCTAssertEqual(loaded.alarms, state.alarms)
        XCTAssertEqual(loaded.history, state.history)
        try? FileManager.default.removeItem(at: url)
    }

    func testAlarmEditingKeepsListSorted() {
        let model = AppModel(state: PersistedState(), persists: false)
        model.upsert(WakeAlarm(hour: 9, minute: 0))
        model.upsert(WakeAlarm(hour: 6, minute: 30))
        XCTAssertEqual(model.alarms.map(\.hour), [6, 9])
        let id = model.alarms[0].id
        model.setEnabled(id, false)
        XCTAssertFalse(model.alarms[0].isEnabled)
        model.deleteAlarm(id)
        XCTAssertEqual(model.alarms.count, 1)
    }

    func testCompletingMissionRecordsWakeAndSchedulesCheck() {
        var alarm = WakeAlarm(hour: 7, minute: 0)
        alarm.repeatDays = Weekday.weekdays
        alarm.snooze.maxCount = 1
        var state = PersistedState()
        state.alarms = [alarm]
        let model = AppModel(state: state, persists: false)
        model.startSleep()

        model.ringFromExternal(alarmID: alarm.id, scheduledAt: Date().addingTimeInterval(-30))
        XCTAssertEqual(model.overlay, .ringing)
        XCTAssertNotNil(model.currentRing)
        XCTAssertTrue(model.canSnooze())

        model.missionActivity()
        XCTAssertNotNil(model.currentRing?.missionStartedAt)
        model.completeMission()

        XCTAssertNil(model.currentRing)
        XCTAssertEqual(model.overlay, .briefing)
        XCTAssertEqual(model.state.history.count, 1)
        XCTAssertEqual(model.state.history.first?.alarmID, alarm.id)
        XCTAssertNotNil(model.pendingWakeUpCheck)
        XCTAssertNil(model.activeSleep, "Dismissing the alarm ends the sleep session")
        XCTAssertTrue(model.alarms[0].isEnabled, "Repeating alarms stay on")

        model.confirmAwake()
        XCTAssertNil(model.pendingWakeUpCheck)
        XCTAssertEqual(model.state.history.first?.passedWakeUpCheck, true)
    }

    func testSnoozeIsLimited() {
        var alarm = WakeAlarm(hour: 7, minute: 0)
        alarm.snooze.maxCount = 1
        var state = PersistedState()
        state.alarms = [alarm]
        let model = AppModel(state: state, persists: false)
        model.ringFromExternal(alarmID: alarm.id, scheduledAt: Date())
        model.snooze()
        XCTAssertNil(model.currentRing)
        XCTAssertNotNil(model.snoozedUntil)
        // The snoozed alarm comes back with one snooze used.
        model.ringFromExternal(alarmID: alarm.id)
        XCTAssertEqual(model.currentRing?.snoozeCount, 1)
        XCTAssertFalse(model.canSnooze())
        model.completeMission()
        XCTAssertEqual(model.state.history.first?.snoozeCount, 1)
        XCTAssertFalse(model.alarms[0].isEnabled, "One-time alarms turn off after ringing")
    }

    func testPreviewDoesNotRecordHistory() {
        let model = AppModel(state: PersistedState(), persists: false)
        model.preview(WakeAlarm(hour: 7, minute: 0))
        XCTAssertEqual(model.overlay, .ringing)
        model.completeMission()
        XCTAssertNil(model.overlay)
        XCTAssertTrue(model.state.history.isEmpty)
    }

    func testWeatherParsing() throws {
        let json = """
        {"current":{"temperature_2m":12.4,"weather_code":61},
         "daily":{"temperature_2m_max":[15.0],"temperature_2m_min":[8.5],"precipitation_probability_max":[70]}}
        """
        let weather = try BriefingService.parseWeather(Data(json.utf8))
        XCTAssertEqual(weather.temperature, 12.4)
        XCTAssertEqual(weather.precipitationChance, 70)
        XCTAssertEqual(weather.description, "Rain")
    }
}
