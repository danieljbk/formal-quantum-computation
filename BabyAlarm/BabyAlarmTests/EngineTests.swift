import XCTest
@testable import BabyAlarm

final class EngineTests: XCTestCase {
    func testAlarmRingsAtItsTimeWithChosenBabyVoice() {
        var a = T.alarm(7, 0, repeats: Weekday.weekdays)
        a.voiceID = "cry_hungry"
        var core = T.core([a], lastTick: T.date("2026-11-25 06:59:30"))
        core.tick(now: T.date("2026-11-25 06:59:59"))
        XCTAssertNil(core.ringing)
        core.tick(now: T.date("2026-11-25 07:00:00"))
        XCTAssertEqual(core.ringing?.alarm.id, a.id)
        XCTAssertEqual(core.ringing?.voice.id, "cry_hungry")
        XCTAssertEqual(core.ringing?.key.occurrence, T.date("2026-11-25 07:00"))
    }

    func testDismissStopsAndDoesNotReRing() {
        var core = T.core([T.alarm(7, 0, repeats: Weekday.weekdays)], lastTick: T.date("2026-11-25 06:59:00"))
        core.tick(now: T.date("2026-11-25 07:00:01"))
        XCTAssertNotNil(core.ringing)
        core.dismiss(now: T.date("2026-11-25 07:01:00"))
        XCTAssertNil(core.ringing)
        core.tick(now: T.date("2026-11-25 07:01:01"))
        XCTAssertNil(core.ringing)
        XCTAssertTrue(core.alarms[0].isEnabled, "repeating alarms stay on")
    }

    func testNonRepeatingAlarmTurnsItselfOff() {
        var core = T.core([T.alarm(7, 0)], lastTick: T.date("2026-11-25 06:59:00"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        XCTAssertNotNil(core.ringing)
        XCTAssertFalse(core.alarms[0].isEnabled)
        core.dismiss(now: T.date("2026-11-25 07:00:30"))
        XCTAssertEqual(core.alarms.count, 1)
    }

    func testMissedAlarmIsNotStartedHoursLate() {
        var core = T.core([T.alarm(7, 0, repeats: Weekday.weekdays)], lastTick: T.date("2026-11-25 06:00:00"))
        core.tick(now: T.date("2026-11-25 09:00:00"))
        XCTAssertNil(core.ringing)
    }

    func testSnoozeRingsAgainAndRespectsLimit() {
        var a = T.alarm(7, 0, repeats: Weekday.weekdays)
        a.snooze = SnoozeSettings(isEnabled: true, minutes: 5, maxCount: 2)
        var core = T.core([a], lastTick: T.date("2026-11-25 06:59:00"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        XCTAssertEqual(core.ringing?.canSnooze, true)

        core.snooze(now: T.date("2026-11-25 07:00:10"))
        XCTAssertNil(core.ringing)
        core.tick(now: T.date("2026-11-25 07:05:09"))
        XCTAssertNil(core.ringing)
        core.tick(now: T.date("2026-11-25 07:05:10"))
        XCTAssertEqual(core.ringing?.snoozeCount, 1)

        core.snooze(now: T.date("2026-11-25 07:05:20"))
        core.tick(now: T.date("2026-11-25 07:10:20"))
        XCTAssertEqual(core.ringing?.snoozeCount, 2)
        XCTAssertEqual(core.ringing?.canSnooze, false)
        core.snooze(now: T.date("2026-11-25 07:10:30"))
        XCTAssertNotNil(core.ringing, "snooze is refused once the limit is reached")
    }

    func testWakeUpCheckConfirmed() {
        var a = T.alarm(7, 0, repeats: Weekday.weekdays)
        a.wakeUpCheck = WakeUpCheckSettings(isEnabled: true, delayMinutes: 5, confirmWindowSeconds: 100)
        var core = T.core([a], lastTick: T.date("2026-11-25 06:59:00"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        core.dismiss(now: T.date("2026-11-25 07:01:00"))
        core.tick(now: T.date("2026-11-25 07:05:59"))
        XCTAssertNil(core.wakeCheck)
        core.tick(now: T.date("2026-11-25 07:06:00"))
        XCTAssertEqual(core.wakeCheck?.deadline, T.date("2026-11-25 07:07:40"))
        core.confirmAwake(now: T.date("2026-11-25 07:06:30"))
        XCTAssertNil(core.wakeCheck)
        core.tick(now: T.date("2026-11-25 07:08:00"))
        XCTAssertNil(core.ringing)
        XCTAssertTrue(core.state.pending.isEmpty)
    }

    func testWakeUpCheckTimeoutMakesTheBabyCryAgain() {
        var a = T.alarm(7, 0, repeats: Weekday.weekdays)
        a.wakeUpCheck = WakeUpCheckSettings(isEnabled: true, delayMinutes: 5, confirmWindowSeconds: 100)
        var core = T.core([a], lastTick: T.date("2026-11-25 06:59:00"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        core.dismiss(now: T.date("2026-11-25 07:01:00"))
        core.tick(now: T.date("2026-11-25 07:06:00"))
        XCTAssertNotNil(core.wakeCheck)
        core.tick(now: T.date("2026-11-25 07:07:40"))
        XCTAssertNil(core.wakeCheck)
        XCTAssertEqual(core.ringing?.alarm.id, a.id)
    }

    func testQuickAlarmRingsOnceThenIsRemoved() {
        var core = T.core([], lastTick: T.date("2026-11-25 13:00:00"))
        let q = core.addQuickAlarm(minutes: 20, voiceID: "cry_fussy", now: T.date("2026-11-25 13:00:00"))
        XCTAssertEqual(q.oneShotDate, T.date("2026-11-25 13:20"))
        core.tick(now: T.date("2026-11-25 13:19:59"))
        XCTAssertNil(core.ringing)
        core.tick(now: T.date("2026-11-25 13:20:00"))
        XCTAssertEqual(core.ringing?.voice.id, "cry_fussy")
        core.dismiss(now: T.date("2026-11-25 13:20:30"))
        XCTAssertTrue(core.alarms.isEmpty)
    }

    func testOpeningFromNotificationStartsRinging() {
        let a = T.alarm(7, 0, repeats: Weekday.weekdays)
        var core = T.core([a], lastTick: T.date("2026-11-25 05:00:00"))
        let key = OccurrenceKey(alarmID: a.id, occurrence: T.date("2026-11-25 07:00"))
        let id = NotificationID(kind: .alarm, key: key, index: 3, extra: 0).string
        core.handleNotification(identifier: id, now: T.date("2026-11-25 07:01:31"))
        XCTAssertEqual(core.ringing?.key, key)
        core.dismiss(now: T.date("2026-11-25 07:02:00"))
        core.handleNotification(identifier: id, now: T.date("2026-11-25 07:02:01"))
        XCTAssertNil(core.ringing, "an already-dismissed occurrence does not ring again")
    }

    func testSnoozeActionFromNotification() {
        var a = T.alarm(7, 0, repeats: Weekday.weekdays)
        a.snooze = SnoozeSettings(isEnabled: true, minutes: 10, maxCount: 0)
        var core = T.core([a], lastTick: T.date("2026-11-25 05:00:00"))
        let key = OccurrenceKey(alarmID: a.id, occurrence: T.date("2026-11-25 07:00"))
        core.snoozeFromNotification(identifier: NotificationID(kind: .alarm, key: key, index: 0, extra: 0).string,
                                    now: T.date("2026-11-25 07:00:05"))
        XCTAssertEqual(core.state.pending.first?.fireDate, T.date("2026-11-25 07:10:05"))
        XCTAssertEqual(core.state.pending.first?.kind, .snooze(count: 1))
    }

    func testDeletingAlarmClearsItsPendingEvents() {
        var core = T.core([T.alarm(7, 0, repeats: Weekday.weekdays)], lastTick: T.date("2026-11-25 06:59:00"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        core.snooze(now: T.date("2026-11-25 07:00:10"))
        XCTAssertEqual(core.state.pending.count, 1)
        core.delete(id: core.alarms[0].id)
        XCTAssertTrue(core.state.pending.isEmpty)
    }

    func testPersistenceRoundTrip() {
        let suite = "babyalarm.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repo = AlarmRepository(defaults: defaults)
        XCTAssertNil(repo.load())
        var state = AlarmRepository.starterState(now: T.date("2026-11-25 00:00"))
        var a = T.alarm(5, 45, repeats: [.monday])
        a.voiceID = BabyVoiceCatalog.randomID
        a.missions = [MissionSettings(kind: .shake, difficulty: .hard, rounds: 40), MissionSettings(kind: .barcode, barcodePayload: "4006381333931")]
        state.alarms.append(a)
        state.pending = [PendingEvent(key: OccurrenceKey(alarmID: a.id, occurrence: T.date("2026-11-30 05:45")),
                                      fireDate: T.date("2026-11-30 05:50"), kind: .snooze(count: 1))]
        repo.save(state)
        XCTAssertEqual(repo.load(), state)
    }
}
