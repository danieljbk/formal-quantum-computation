import AVFoundation
import XCTest
@testable import CryWake

final class StoreAndCatalogTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("state.json")
    }

    // MARK: Store

    func testAlarmsAndHistoryPersistAcrossLaunches() {
        let url = tempURL()
        var alarm = Alarm(hour: 6, minute: 15, label: "Gym", repeatDays: [.monday, .thursday])
        alarm.voiceID = "big_fuss"
        alarm.mission = .typing
        alarm.missionDifficulty = .hard
        alarm.maxSnoozes = nil
        alarm.wakeUpCheck = true

        let store = AlarmStore(fileURL: url)
        store.upsert(alarm)
        let record = WakeRecord(alarmID: alarm.id, alarmLabel: "Gym", voiceID: "big_fuss",
                                firstRangAt: Date(timeIntervalSince1970: 1_000),
                                dismissedAt: Date(timeIntervalSince1970: 1_120),
                                snoozeCount: 1, mission: .typing, wakeCheck: .pending)
        store.record(record)
        store.updateWakeCheck(alarmID: alarm.id, result: .passed)

        let reloaded = AlarmStore(fileURL: url)
        XCTAssertEqual(reloaded.alarms, [alarm])
        XCTAssertEqual(reloaded.history.first?.wakeCheck, .passed)
        XCTAssertEqual(reloaded.history.first?.secondsToDismiss, 120)
    }

    func testUpsertToggleDelete() {
        let store = AlarmStore(fileURL: nil)
        var a = Alarm(hour: 9, minute: 0)
        let b = Alarm(hour: 5, minute: 0)
        store.upsert(a)
        store.upsert(b)
        XCTAssertEqual(store.sortedAlarms.map(\.id), [b.id, a.id])
        a.label = "Late"
        store.upsert(a)
        XCTAssertEqual(store.alarms.count, 2)
        XCTAssertEqual(store.alarm(id: a.id)?.label, "Late")
        store.setEnabled(false, id: b.id)
        XCTAssertEqual(store.alarm(id: b.id)?.isEnabled, false)
        let next = store.nextAlarm(after: Date())
        XCTAssertEqual(next?.alarm.id, a.id)
        store.delete(id: a.id)
        XCTAssertNil(store.nextAlarm(after: Date()))
    }

    func testStats() {
        let id = UUID()
        func rec(_ minutesAgo: Double, snoozes: Int, check: WakeCheckResult = .notRequired) -> WakeRecord {
            let d = Date(timeIntervalSince1970: 100_000 - minutesAgo * 60)
            return WakeRecord(alarmID: id, alarmLabel: "", voiceID: "", firstRangAt: d.addingTimeInterval(-60),
                              dismissedAt: d, snoozeCount: snoozes, mission: .none, wakeCheck: check)
        }
        let stats = WakeStats(records: [rec(0, snoozes: 0), rec(10, snoozes: 0, check: .passed),
                                        rec(20, snoozes: 2), rec(30, snoozes: 0)])
        XCTAssertEqual(stats.total, 4)
        XCTAssertEqual(stats.averageSnoozes, 0.5)
        XCTAssertEqual(stats.averageMinutesToDismiss, 1)
        XCTAssertEqual(stats.cleanStreak, 2)
        XCTAssertEqual(WakeStats(records: []).total, 0)
    }

    // MARK: Bundled recorded voices

    func testAtLeastThreeRecordedVoicesAreBundledAndPlayable() throws {
        let voices = BabyVoice.loadCatalog(from: .main)
        XCTAssertGreaterThanOrEqual(voices.count, 3)
        XCTAssertEqual(Set(voices.map(\.id)).count, voices.count, "voice ids must be unique")
        XCTAssertNotNil(voices.first { $0.id == BabyVoice.defaultVoiceID })
        for voice in voices {
            let url = try XCTUnwrap(voice.url(), "missing \(voice.file) in app bundle")
            XCTAssertEqual(url.pathExtension, "caf")
            let file = try AVAudioFile(forReading: url)
            let seconds = Double(file.length) / file.processingFormat.sampleRate
            // Notification sounds longer than 30 s fall back to the default sound.
            XCTAssertGreaterThan(seconds, 3, voice.id)
            XCTAssertLessThanOrEqual(seconds, 30, voice.id)
            XCTAssertNoThrow(try AVAudioPlayer(contentsOf: url), voice.id)
        }
    }

    func testEveryVoiceHasVerifiedLicenseAndProvenance() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "voices", withExtension: "json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let voices = try XCTUnwrap(json["voices"] as? [[String: Any]])
        let allowed = ["CC0 1.0", "CC BY-SA 4.0"]
        for v in voices {
            XCTAssertTrue(allowed.contains(v["license"] as? String ?? ""), "\(v["id"] ?? "?")")
            XCTAssertNotNil(URL(string: v["source_page"] as? String ?? ""))
            let prov = try XCTUnwrap(v["provenance"] as? [String: Any])
            XCTAssertEqual(prov["origin"] as? String, "recorded")
            let stages = try XCTUnwrap(prov["stages"] as? [String: Any])
            XCTAssertNotNil(stages["fetch"])
            XCTAssertNotNil(stages["condition"])
            XCTAssertNotNil(stages["encode"])
        }
    }

    func testUnknownVoiceFallsBackToDefault() {
        XCTAssertEqual(BabyVoice.voice(id: "no-such-voice")?.id, BabyVoice.defaultVoiceID)
    }

    // MARK: Notification backup

    func testNotificationBurstsStayWithinSystemLimit() {
        let voices = BabyVoice.loadCatalog(from: .main)
        let now = Date()
        let alarms = (0..<12).map { i in Alarm(hour: i, minute: 0) }
        let triggers = alarms.enumerated().map { i, a in
            PendingTrigger(alarmID: a.id, date: now.addingTimeInterval(Double(i + 1) * 3600), reason: .scheduled)
        }
        let plans = NotificationPlanner.plans(triggers: triggers, alarms: alarms, voices: voices, now: now)
        XCTAssertLessThanOrEqual(plans.count, NotificationPlanner.systemLimit)
        XCTAssertEqual(Set(alarms.map(\.id)), Set(plans.map(\.alarmID)), "every alarm keeps a backup")
        XCTAssertEqual(Set(plans.map(\.identifier)).count, plans.count)
        for plan in plans {
            XCTAssertEqual(NotificationPlanner.alarmID(fromIdentifier: plan.identifier), plan.alarmID)
            XCTAssertTrue(voices.contains { $0.file == plan.soundFile })
        }
    }

    func testSingleAlarmGetsFullBurstOfCryingNotifications() {
        let voices = BabyVoice.loadCatalog(from: .main)
        let now = Date()
        var alarm = Alarm(hour: 7, minute: 0)
        alarm.voiceID = voices.last!.id
        let t = PendingTrigger(alarmID: alarm.id, date: now.addingTimeInterval(60), reason: .scheduled)
        let past = PendingTrigger(alarmID: alarm.id, date: now.addingTimeInterval(-60), reason: .snooze)
        let plans = NotificationPlanner.plans(triggers: [t, past], alarms: [alarm], voices: voices, now: now)
        XCTAssertEqual(plans.count, NotificationPlanner.maxBurst)
        XCTAssertEqual(plans.first?.fireDate, t.date)
        XCTAssertEqual(plans.last?.fireDate,
                       t.date.addingTimeInterval(Double(NotificationPlanner.maxBurst - 1) * NotificationPlanner.burstSpacing))
        XCTAssertTrue(plans.allSatisfy { $0.soundFile == voices.last!.file })
    }
}
