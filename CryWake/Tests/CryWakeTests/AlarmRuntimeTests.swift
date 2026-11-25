import XCTest
@testable import CryWake

final class AlarmRuntimeTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func at(_ h: Int, _ m: Int, _ s: Int = 0, day: Int = 25) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m, second: s))!
    }

    func testRingsAtScheduledTimeAndNotBefore() {
        let alarm = Alarm(hour: 7, minute: 0)
        var rt = AlarmRuntime()
        rt.rearm([alarm], now: at(6, 0), calendar: calendar)
        XCTAssertNil(rt.popDue(now: at(6, 59, 59), alarms: [alarm], calendar: calendar))
        let due = rt.popDue(now: at(7, 0, 1), alarms: [alarm], calendar: calendar)
        XCTAssertEqual(due, PendingTrigger(alarmID: alarm.id, date: at(7, 0), reason: .scheduled))
        // consumed: does not ring twice
        XCTAssertNil(rt.popDue(now: at(7, 0, 2), alarms: [alarm], calendar: calendar))
    }

    func testDisabledAlarmNeverRings() {
        var alarm = Alarm(hour: 7, minute: 0)
        alarm.isEnabled = false
        var rt = AlarmRuntime()
        rt.rearm([alarm], now: at(6, 0), calendar: calendar)
        XCTAssertTrue(rt.triggers.isEmpty)
        XCTAssertNil(rt.popDue(now: at(7, 1), alarms: [alarm], calendar: calendar))
    }

    func testRepeatingAlarmRearmsForNextDay() {
        let alarm = Alarm(hour: 7, minute: 0, repeatDays: Set(Weekday.allCases))
        var rt = AlarmRuntime()
        rt.rearm([alarm], now: at(6, 0), calendar: calendar)
        XCTAssertNotNil(rt.popDue(now: at(7, 0), alarms: [alarm], calendar: calendar))
        XCTAssertEqual(rt.scheduled[alarm.id], at(7, 0, day: 26))
    }

    func testStaleTriggerBeyondGraceIsDropped() {
        let alarm = Alarm(hour: 7, minute: 0)
        var rt = AlarmRuntime()
        rt.rearm([alarm], now: at(6, 0), calendar: calendar)
        XCTAssertNil(rt.popDue(now: at(9, 0), alarms: [alarm], grace: 600, calendar: calendar))
        XCTAssertNil(rt.scheduled[alarm.id])
    }

    func testSnoozeRingsAgainAfterSnoozeLength() {
        var alarm = Alarm(hour: 7, minute: 0)
        alarm.snoozeMinutes = 9
        alarm.maxSnoozes = 1
        var rt = AlarmRuntime()
        rt.rearm([alarm], now: at(6, 0), calendar: calendar)
        _ = rt.popDue(now: at(7, 0), alarms: [alarm], calendar: calendar)

        XCTAssertEqual(rt.snooze(alarm, now: at(7, 0, 30)), at(7, 9, 30))
        XCTAssertEqual(rt.snoozeCount(for: alarm.id), 1)
        XCTAssertNil(rt.popDue(now: at(7, 9), alarms: [alarm], calendar: calendar))
        XCTAssertEqual(rt.popDue(now: at(7, 9, 30), alarms: [alarm], calendar: calendar)?.reason, .snooze)
        // limit reached
        XCTAssertNil(rt.snooze(alarm, now: at(7, 10)))
        XCTAssertEqual(rt.dismiss(alarm, now: at(7, 10)), 1)
        XCTAssertEqual(rt.snoozeCount(for: alarm.id), 0)
    }

    func testWakeUpCheckReringsUnlessConfirmed() {
        var alarm = Alarm(hour: 7, minute: 0)
        alarm.wakeUpCheck = true
        alarm.wakeUpCheckMinutes = 3
        var rt = AlarmRuntime()
        rt.rearm([alarm], now: at(6, 0), calendar: calendar)
        _ = rt.popDue(now: at(7, 0), alarms: [alarm], calendar: calendar)
        rt.dismiss(alarm, now: at(7, 1))
        XCTAssertEqual(rt.wakeChecks[alarm.id], at(7, 4))

        // One-off alarms switch themselves off after dismissal; the check must survive that.
        var off = alarm
        off.isEnabled = false
        rt.rearm([off], now: at(7, 1, 1), calendar: calendar)
        XCTAssertEqual(rt.popDue(now: at(7, 4), alarms: [off], calendar: calendar)?.reason, .wakeCheck)

        // Confirmed in time -> nothing rings.
        var rt2 = AlarmRuntime()
        rt2.rearm([alarm], now: at(6, 0), calendar: calendar)
        _ = rt2.popDue(now: at(7, 0), alarms: [alarm], calendar: calendar)
        rt2.dismiss(alarm, now: at(7, 1))
        rt2.confirmAwake(alarm.id)
        XCTAssertNil(rt2.popDue(now: at(7, 5), alarms: [alarm], calendar: calendar))
    }

    func testDeletingAlarmCancelsSnoozeAndWakeCheck() {
        var alarm = Alarm(hour: 7, minute: 0)
        alarm.wakeUpCheck = true
        var rt = AlarmRuntime()
        rt.rearm([alarm], now: at(6, 0), calendar: calendar)
        _ = rt.popDue(now: at(7, 0), alarms: [alarm], calendar: calendar)
        rt.snooze(alarm, now: at(7, 0))
        rt.rearm([], now: at(7, 1), calendar: calendar)
        XCTAssertTrue(rt.triggers.isEmpty)
    }

    func testTriggersAreOrderedByDate() {
        let a = Alarm(hour: 8, minute: 0)
        let b = Alarm(hour: 6, minute: 30)
        var rt = AlarmRuntime()
        rt.rearm([a, b], now: at(5, 0), calendar: calendar)
        XCTAssertEqual(rt.nextTrigger?.alarmID, b.id)
        XCTAssertEqual(rt.triggers.map(\.alarmID), [b.id, a.id])
    }
}
