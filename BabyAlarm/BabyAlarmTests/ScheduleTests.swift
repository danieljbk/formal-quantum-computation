import XCTest
@testable import BabyAlarm

final class ScheduleTests: XCTestCase {
    let cal = T.utc

    func testOneTimeAlarmLaterToday() {
        let a = T.alarm(7, 0)
        XCTAssertEqual(AlarmSchedule.nextFireDate(for: a, after: T.date("2026-11-25 06:00"), calendar: cal),
                       T.date("2026-11-25 07:00"))
    }

    func testOneTimeAlarmRollsToTomorrow() {
        let a = T.alarm(7, 0)
        XCTAssertEqual(AlarmSchedule.nextFireDate(for: a, after: T.date("2026-11-25 07:00"), calendar: cal),
                       T.date("2026-11-26 07:00"))
    }

    func testWeekdayRepeatSkipsWeekend() {
        let a = T.alarm(6, 30, repeats: Weekday.weekdays)
        // Friday 2026-11-27 after 06:30 -> Monday 2026-11-30 06:30
        XCTAssertEqual(AlarmSchedule.nextFireDate(for: a, after: T.date("2026-11-27 08:00"), calendar: cal),
                       T.date("2026-11-30 06:30"))
    }

    func testUpcomingFireDatesForRepeatingAlarm() {
        let a = T.alarm(9, 0, repeats: Weekday.weekend)
        let dates = AlarmSchedule.upcomingFireDates(for: a, after: T.date("2026-11-25 00:00"), count: 3, calendar: cal)
        XCTAssertEqual(dates, [T.date("2026-11-28 09:00"), T.date("2026-11-29 09:00"), T.date("2026-12-05 09:00")])
    }

    func testDisabledAndExpiredAlarmsNeverFire() {
        var a = T.alarm(7, 0)
        a.isEnabled = false
        XCTAssertNil(AlarmSchedule.nextFireDate(for: a, after: T.date("2026-11-25 06:00"), calendar: cal))
        var q = T.alarm(7, 0)
        q.oneShotDate = T.date("2026-11-25 05:00")
        XCTAssertNil(AlarmSchedule.nextFireDate(for: q, after: T.date("2026-11-25 06:00"), calendar: cal))
    }

    func testNextAlarmPicksEarliest() {
        let a = T.alarm(8, 0)
        let b = T.alarm(6, 45)
        let next = AlarmSchedule.nextAlarm(in: [a, b], after: T.date("2026-11-25 05:00"), calendar: cal)
        XCTAssertEqual(next?.alarm.id, b.id)
        XCTAssertEqual(next?.date, T.date("2026-11-25 06:45"))
    }

    func testCountdownText() {
        let now = T.date("2026-11-25 00:00")
        XCTAssertEqual(AlarmSchedule.countdownText(from: now, to: T.date("2026-11-25 07:12")), "Rings in 7 h 12 min")
        XCTAssertEqual(AlarmSchedule.countdownText(from: now, to: T.date("2026-11-25 00:25")), "Rings in 25 min")
        XCTAssertEqual(AlarmSchedule.countdownText(from: now, to: now.addingTimeInterval(20)), "Rings in less than a minute")
        XCTAssertEqual(AlarmSchedule.countdownText(from: now, to: T.date("2026-11-27 03:00")), "Rings in 2 d 3 h")
    }

    func testRepeatSummary() {
        XCTAssertEqual(AlarmSchedule.repeatSummary([]), "Once")
        XCTAssertEqual(AlarmSchedule.repeatSummary(Set(Weekday.allCases)), "Every day")
        XCTAssertEqual(AlarmSchedule.repeatSummary(Weekday.weekdays), "Weekdays")
        XCTAssertEqual(AlarmSchedule.repeatSummary(Weekday.weekend), "Weekends")
        XCTAssertEqual(AlarmSchedule.repeatSummary([.sunday, .monday, .wednesday]), "Mon, Wed, Sun")
    }

    func testRandomVoiceIsStablePerDayAndAlwaysABabyCry() {
        let d1 = T.date("2026-11-25 07:00")
        let d2 = T.date("2026-11-25 23:00")
        XCTAssertEqual(BabyVoiceCatalog.resolve(BabyVoiceCatalog.randomID, for: d1, calendar: cal),
                       BabyVoiceCatalog.resolve(BabyVoiceCatalog.randomID, for: d2, calendar: cal))
        var seen = Set<String>()
        for day in 0..<14 {
            let v = BabyVoiceCatalog.resolve(BabyVoiceCatalog.randomID, for: d1.addingTimeInterval(Double(day) * 86400), calendar: cal)
            XCTAssertTrue(BabyVoiceCatalog.all.contains(v))
            seen.insert(v.id)
        }
        XCTAssertGreaterThan(seen.count, 1)
        XCTAssertEqual(BabyVoiceCatalog.resolve("unknown", for: d1).id, BabyVoiceCatalog.defaultVoice.id)
    }

    func testEveryCatalogVoiceIsABabyCryClip() {
        XCTAssertGreaterThanOrEqual(BabyVoiceCatalog.all.count, 4)
        XCTAssertEqual(Set(BabyVoiceCatalog.all.map(\.id)).count, BabyVoiceCatalog.all.count)
        for v in BabyVoiceCatalog.all {
            XCTAssertTrue(v.id.hasPrefix("cry_"))
            XCTAssertEqual((v.fileName as NSString).pathExtension, BabyVoice.fileExtension)
            XCTAssertEqual((v.fileName as NSString).deletingPathExtension, v.id)
        }
        XCTAssertEqual(Alarm().voiceID, BabyVoiceCatalog.defaultVoice.id)
    }
}
