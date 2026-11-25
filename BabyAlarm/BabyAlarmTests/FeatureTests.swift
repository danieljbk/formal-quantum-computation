import XCTest
@testable import BabyAlarm

/// Missions chaining, new missions, history/insights, sleep detection, escalation, briefing.
final class FeatureTests: XCTestCase {
    // MARK: Missions

    func testAtLeastSevenRealMissionsBesidesTap() {
        let real = MissionKind.selectable.filter { $0 != .tap }
        XCTAssertGreaterThanOrEqual(real.count, 7)
        XCTAssertEqual(Set(real), [.math, .typing, .memory, .shake, .steps, .squat, .photo, .barcode])
    }

    func testMissionChainRunsInOrderAndSkipsUnregistered() {
        var chain = MissionChain(missions: [
            MissionSettings(kind: .tap, rounds: 10),
            MissionSettings(kind: .barcode),                       // never registered -> skipped
            MissionSettings(kind: .steps, rounds: 20),
        ])
        XCTAssertEqual(chain.missions.map(\.kind), [.tap, .steps])
        XCTAssertEqual(chain.stepText, "Mission 1 of 2")
        var s = chain.current!
        s.registerAction(count: 10)
        chain.update(s)
        XCTAssertEqual(chain.current?.settings.kind, .steps)
        XCTAssertEqual(chain.stepText, "Mission 2 of 2")
        s = chain.current!
        s.setProgress(19)
        chain.update(s)
        XCTAssertFalse(chain.isComplete)
        s = chain.current!
        s.setProgress(25)
        chain.update(s)
        XCTAssertTrue(chain.isComplete)
        XCTAssertNil(chain.current)
    }

    func testMemoryMission() {
        var session = MissionSession(settings: MissionSettings(kind: .memory, difficulty: .medium, rounds: 2),
                                     rng: SeededGenerator(seed: 11))
        let first = session.memory!
        XCTAssertEqual(first.gridSize, 4)
        XCTAssertEqual(first.lit.count, 5)
        XCTAssertFalse(session.submitMemory([]))
        XCTAssertEqual(session.mistakes, 1)
        XCTAssertTrue(session.submitMemory(session.memory!.lit))
        XCTAssertEqual(session.memory!.lit.count, 6, "later rounds light more tiles")
        XCTAssertTrue(session.submitMemory(session.memory!.lit))
        XCTAssertTrue(session.isComplete)
    }

    func testBarcodeAndPhotoMissions() {
        var scan = MissionSession(settings: MissionSettings(kind: .barcode, barcodePayload: " 4006381333931 "))
        XCTAssertFalse(scan.submit("1234"))
        XCTAssertTrue(scan.submit("4006381333931"))
        XCTAssertTrue(scan.isComplete)
        XCTAssertTrue(BarcodeMatcher.matches(scanned: "https://Example.com/x", registered: "HTTPS://EXAMPLE.COM/X"))
        XCTAssertFalse(BarcodeMatcher.matches(scanned: "x", registered: nil))

        var photo = MissionSession(settings: MissionSettings(kind: .photo, photoFile: "ref.jpg"))
        XCTAssertFalse(photo.confirmPhotoMatch(distance: 1.4))
        XCTAssertFalse(photo.confirmPhotoMatch(distance: .nan))
        XCTAssertTrue(photo.confirmPhotoMatch(distance: 0.3))
        XCTAssertTrue(photo.isComplete)
        XCTAssertFalse(MissionSettings(kind: .photo).isReady)
    }

    func testSquatDetector() {
        var d = SquatDetector()
        var reps = 0
        var t = 0.0
        for _ in 0..<3 {
            for a in [0.0, -0.4, -0.3, 0.0, 0.4, 0.1, 0.0] {
                if d.ingest(vertical: a, at: t) { reps += 1 }
                t += 0.2
            }
            t += 0.5
        }
        XCTAssertEqual(reps, 3)
        XCTAssertFalse(d.ingest(vertical: 0.5, at: t + 1), "a push without a dip is not a squat")
    }

    func testLegacyAlarmWithSingleMissionDecodes() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","hour":6,"minute":15,"label":"Old","isEnabled":true,"repeatDays":[2],
         "voiceID":"cry_fussy","snooze":{"isEnabled":true,"minutes":5,"maxCount":3},
         "mission":{"kind":"shake","difficulty":"easy","rounds":30},
         "volume":1,"gradualVolumeSeconds":30,"vibrate":true,
         "wakeUpCheck":{"isEnabled":false,"delayMinutes":5,"confirmWindowSeconds":100}}
        """
        let alarm = try JSONDecoder().decode(Alarm.self, from: Data(legacy.utf8))
        XCTAssertEqual(alarm.missions.map(\.kind), [.shake])
        XCTAssertTrue(alarm.cryEscalation)
        XCTAssertNil(alarm.skippedOccurrence)
    }

    // MARK: Home actions

    func testSkipNextAndDuplicate() {
        let a = T.alarm(7, 0, repeats: Weekday.weekdays)
        var core = T.core([a], lastTick: T.date("2026-11-25 05:00"))
        core.skipNext(id: a.id, now: T.date("2026-11-25 05:00"))
        XCTAssertEqual(AlarmSchedule.nextFireDate(for: core.alarms[0], after: T.date("2026-11-25 05:00"), calendar: T.utc),
                       T.date("2026-11-26 07:00"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        XCTAssertNil(core.ringing, "skipped occurrence stays silent")
        core.clearSkip(id: a.id)
        XCTAssertNil(core.alarms[0].skippedOccurrence)

        core.duplicate(id: a.id)
        XCTAssertEqual(core.alarms.count, 2)
        XCTAssertNotEqual(core.alarms[0].id, core.alarms[1].id)
        XCTAssertEqual(core.alarms[0].hour, core.alarms[1].hour)
    }

    // MARK: History and insights

    func testDismissRecordsHistoryAndWakeCheckResult() {
        var a = T.alarm(7, 0, repeats: Weekday.weekdays, mission: MissionSettings(kind: .math))
        a.wakeUpCheck = WakeUpCheckSettings(isEnabled: true, delayMinutes: 5, confirmWindowSeconds: 100)
        var core = T.core([a], lastTick: T.date("2026-11-25 06:59"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        core.snooze(now: T.date("2026-11-25 07:00:30"))
        core.tick(now: T.date("2026-11-25 07:05:30"))
        core.dismiss(now: T.date("2026-11-25 07:08:00"))
        XCTAssertEqual(core.state.history.count, 1)
        let rec = core.state.history[0]
        XCTAssertEqual(rec.snoozeCount, 1)
        XCTAssertEqual(rec.minutesToGetUp, 8, accuracy: 0.01)
        XCTAssertEqual(rec.missionKinds, [.math])
        XCTAssertNil(rec.wakeCheckPassed)

        core.tick(now: T.date("2026-11-25 07:13:00"))
        core.tick(now: T.date("2026-11-25 07:14:40"))   // missed the check
        XCTAssertEqual(core.state.history[0].wakeCheckPassed, false)
        core.dismiss(now: T.date("2026-11-25 07:15:00"))
        XCTAssertEqual(core.state.history.count, 1, "re-ring extends the same morning")
        XCTAssertEqual(core.state.history[0].dismissedAt, T.date("2026-11-25 07:15:00"))
    }

    func testInsightsStreaks() {
        func rec(_ day: String, snoozes: Int = 0, check: Bool? = nil) -> WakeRecord {
            let d = T.date(day + " 07:00")
            return WakeRecord(alarmID: UUID(), label: "A", voiceID: "cry_fussy", scheduled: d, rangAt: d,
                              dismissedAt: d.addingTimeInterval(180), snoozeCount: snoozes, missionKinds: [.math],
                              wakeCheckPassed: check)
        }
        let records = [rec("2026-11-18"), rec("2026-11-19"), rec("2026-11-20"), rec("2026-11-21"),
                       rec("2026-11-22", snoozes: 4), rec("2026-11-23"), rec("2026-11-24", check: true),
                       rec("2026-11-25", check: false)]
        let s = Insights.summary(records: records, now: T.date("2026-11-25 12:00"), calendar: T.utc)
        XCTAssertEqual(s.currentStreak, 2, "today failed its check, so the streak ends yesterday")
        XCTAssertEqual(s.bestStreak, 4)
        XCTAssertEqual(s.mornings, 8)
        XCTAssertEqual(s.averageMinutesToGetUp!, 3, accuracy: 0.001)
        XCTAssertEqual(s.onTimeRate!, 6.0 / 8.0, accuracy: 0.001)

        let series = Insights.wakeSeries(records: records, days: 7, now: T.date("2026-11-25 12:00"), calendar: T.utc)
        XCTAssertEqual(series.count, 7)
        XCTAssertEqual(series.first?.day, T.date("2026-11-19 00:00"))
    }

    // MARK: Sleep

    func testSoundEventDetectorFindsSnores() {
        var d = SoundEventDetector(threshold: -35, minDuration: 1, mergeGap: 2)
        var t = 0.0
        func feed(_ level: Double, seconds: Double) {
            var s = 0.0
            while s < seconds { d.ingest(level: level, at: t); t += 0.5; s += 0.5 }
        }
        feed(-60, seconds: 10)
        feed(-20, seconds: 2); feed(-50, seconds: 1); feed(-22, seconds: 2)   // one snore cycle
        feed(-60, seconds: 10)
        feed(-25, seconds: 0.5)                                              // a click: too short
        feed(-60, seconds: 10)
        feed(-15, seconds: 3)                                                 // talking, still open at the end
        d.finish()
        XCTAssertEqual(d.events.count, 2)
        XCTAssertEqual(d.events[0].offset, 10, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(d.events[0].duration, 4)
        XCTAssertEqual(d.events[1].peakLevel, -15)
    }

    func testSleepSeriesAndSessionDuration() {
        var s = SleepSession(start: T.date("2026-11-24 23:00"))
        XCTAssertTrue(s.isActive)
        s.end = T.date("2026-11-25 06:30")
        XCTAssertEqual(s.duration, 7.5 * 3600)
        let series = Insights.sleepSeries(sessions: [s], days: 7, now: T.date("2026-11-25 12:00"), calendar: T.utc)
        XCTAssertEqual(series, [DailyPoint(day: T.date("2026-11-25 00:00"), value: 7.5)])
        XCTAssertEqual(SleepSoundCatalog.all.count, 4)
    }

    // MARK: Escalation and briefing

    func testCryEscalationGetsFussier() {
        let fussy = BabyVoiceCatalog.voice(id: "cry_fussy")!
        let stages = CryEscalation.stages(startingWith: fussy, enabled: true)
        XCTAssertEqual(stages.map(\.voice.id), CryEscalation.intensityOrder)
        XCTAssertEqual(CryEscalation.stage(at: 0, in: stages)?.voice.id, "cry_fussy")
        XCTAssertEqual(CryEscalation.stage(at: 50, in: stages)?.voice.id, "cry_hungry")
        XCTAssertEqual(CryEscalation.stage(at: 1000, in: stages)?.voice.id, "cry_newborn")
        XCTAssertEqual(CryEscalation.stages(startingWith: fussy, enabled: false).count, 1)
        XCTAssertEqual(Set(CryEscalation.intensityOrder), Set(BabyVoiceCatalog.all.map(\.id)))
    }

    func testBriefingContent() {
        let day = T.date("2026-11-25 07:00")
        XCTAssertEqual(MorningContent.quote(for: day, calendar: T.utc).text,
                       MorningContent.quote(for: day.addingTimeInterval(3600), calendar: T.utc).text)
        XCTAssertNotEqual(MorningContent.fortune(for: .aries, on: day, calendar: T.utc),
                          MorningContent.fortune(for: .taurus, on: day, calendar: T.utc))
        XCTAssertEqual(MorningContent.greeting(for: day, calendar: T.utc), "Good morning")

        let json = """
        {"current":{"temperature_2m":4.2,"weather_code":61},
         "daily":{"temperature_2m_max":[8.1],"temperature_2m_min":[1.5],"precipitation_probability_max":[70]}}
        """
        let w = WeatherReport.decode(Data(json.utf8))
        XCTAssertEqual(w?.summary, "Rain")
        XCTAssertEqual(w?.high, 8.1)
        XCTAssertEqual(w?.precipitationChance, 70)
        XCTAssertNil(WeatherReport.decode(Data("{}".utf8)))
        let url = WeatherReport.url(latitude: 51.5072, longitude: -0.1276)!.absoluteString
        XCTAssertTrue(url.hasPrefix("https://api.open-meteo.com/v1/forecast?latitude=51.51&longitude=-0.13"))
    }

    func testEngineStateDecodesWithoutHistory() throws {
        let json = #"{"alarms":[],"pending":[],"handled":{},"lastTick":0}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let state = try decoder.decode(EngineState.self, from: Data(json.utf8))
        XCTAssertTrue(state.history.isEmpty)
    }
}
