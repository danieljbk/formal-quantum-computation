import XCTest
@testable import CryWake

final class AlarmScheduleTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    func testOneOffAlarmRingsLaterToday() {
        let alarm = Alarm(hour: 7, minute: 30)
        // Wednesday 2026-11-25 06:00
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 11, 25, 6, 0), calendar: calendar),
                       date(2026, 11, 25, 7, 30))
    }

    func testOneOffAlarmRollsToTomorrowOncePassed() {
        let alarm = Alarm(hour: 7, minute: 30)
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 11, 25, 7, 30), calendar: calendar),
                       date(2026, 11, 26, 7, 30))
    }

    func testWeekdayAlarmSkipsWeekend() {
        let alarm = Alarm(hour: 6, minute: 45, repeatDays: Weekday.weekdays)
        // Friday 2026-11-27 08:00 -> Monday 2026-11-30 06:45
        XCTAssertEqual(alarm.nextFireDate(after: date(2026, 11, 27, 8, 0), calendar: calendar),
                       date(2026, 11, 30, 6, 45))
    }

    func testRepeatTextSummaries() {
        XCTAssertEqual(Alarm(repeatDays: []).repeatText, "Once")
        XCTAssertEqual(Alarm(repeatDays: Set(Weekday.allCases)).repeatText, "Every day")
        XCTAssertEqual(Alarm(repeatDays: Weekday.weekdays).repeatText, "Weekdays")
        XCTAssertEqual(Alarm(repeatDays: Weekday.weekend).repeatText, "Weekends")
        XCTAssertEqual(Alarm(repeatDays: [.wednesday, .monday]).repeatText, "Mon Wed")
    }

    func testDaylightSavingSpringForwardStillRings() {
        // 2026-03-08 02:30 does not exist in Los Angeles; the alarm must still fire that morning.
        let alarm = Alarm(hour: 2, minute: 30)
        let fire = alarm.nextFireDate(after: date(2026, 3, 8, 0, 0), calendar: calendar)!
        XCTAssertEqual(calendar.component(.day, from: fire), 8)
    }

    func testSnoozeLimits() {
        var alarm = Alarm()
        alarm.snoozeMinutes = 5
        alarm.maxSnoozes = 2
        XCTAssertTrue(alarm.canSnooze(afterSnoozes: 1))
        XCTAssertFalse(alarm.canSnooze(afterSnoozes: 2))
        alarm.maxSnoozes = nil
        XCTAssertTrue(alarm.canSnooze(afterSnoozes: 99))
        alarm.snoozeMinutes = 0
        XCTAssertFalse(alarm.canSnooze(afterSnoozes: 0))
    }
}
