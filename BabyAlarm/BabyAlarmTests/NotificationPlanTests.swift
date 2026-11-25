import XCTest
@testable import BabyAlarm

final class NotificationPlanTests: XCTestCase {
    func testIdentifierRoundTrip() {
        let key = OccurrenceKey(alarmID: UUID(), occurrence: T.date("2026-11-25 07:00"))
        let id = NotificationID(kind: .snooze, key: key, index: 4, extra: 2)
        XCTAssertEqual(NotificationID.parse(id.string), id)
        XCTAssertNil(NotificationID.parse("garbage"))
        XCTAssertNil(NotificationID.parse("alarm.not-a-uuid.1.2.3"))
    }

    func testEachRingIsABurstOfBabyCries() {
        var a = T.alarm(7, 0)
        a.voiceID = "cry_nursery"
        let core = T.core([a], lastTick: T.date("2026-11-25 06:00"))
        let plan = NotificationPlanner.plan(core: core, now: T.date("2026-11-25 06:00"), burstCount: 8, spacing: 30)
        XCTAssertEqual(plan.count, 8)
        XCTAssertEqual(plan.first?.fireDate, T.date("2026-11-25 07:00"))
        XCTAssertEqual(plan.last?.fireDate, T.date("2026-11-25 07:03:30"))
        XCTAssertTrue(plan.allSatisfy { $0.soundFile == "cry_nursery.caf" })
        XCTAssertTrue(plan.allSatisfy { $0.id.kind == .alarm })
    }

    func testPlanStaysWithinIOSPendingLimit() {
        let alarms = (0..<10).map { T.alarm(5 + $0, 0, repeats: Set(Weekday.allCases)) }
        let core = T.core(alarms, lastTick: T.date("2026-11-25 00:00"))
        let plan = NotificationPlanner.plan(core: core, now: T.date("2026-11-25 00:00"))
        XCTAssertLessThanOrEqual(plan.count, 64)
        XCTAssertEqual(plan.count, NotificationPlanner.defaultBudget)
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted(), "soonest rings are kept")
        XCTAssertEqual(Set(plan.map(\.id.string)).count, plan.count)
    }

    func testRingInProgressKeepsItsBurstAfterOneTimeAlarmTurnsOff() {
        var core = T.core([T.alarm(7, 0)], lastTick: T.date("2026-11-25 06:59"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        XCTAssertFalse(core.alarms[0].isEnabled)
        let plan = NotificationPlanner.plan(core: core, now: T.date("2026-11-25 07:00:05"))
        XCTAssertEqual(plan.count, 7)
        XCTAssertTrue(plan.allSatisfy { $0.id.key == core.ringing?.key })
    }

    func testDismissedOccurrenceIsDroppedAndSnoozeReplacesIt() {
        var core = T.core([T.alarm(7, 0, repeats: [.wednesday])], lastTick: T.date("2026-11-25 06:59"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        core.snooze(now: T.date("2026-11-25 07:00:20"))
        let snoozed = NotificationPlanner.plan(core: core, now: T.date("2026-11-25 07:00:21"))
        let today = snoozed.filter { $0.fireDate < T.date("2026-11-26 00:00") }
        XCTAssertTrue(today.allSatisfy { $0.id.kind == .snooze && $0.id.extra == 1 })
        XCTAssertEqual(today.first?.fireDate, T.date("2026-11-25 07:05:20"))

        core.tick(now: T.date("2026-11-25 07:05:20"))
        core.dismiss(now: T.date("2026-11-25 07:06:00"))
        let after = NotificationPlanner.plan(core: core, now: T.date("2026-11-25 07:06:01"))
        XCTAssertTrue(after.allSatisfy { $0.fireDate >= T.date("2026-12-02 07:00") }, "next ring is next Wednesday")
    }

    func testWakeCheckPlansConfirmationThenReRing() {
        var a = T.alarm(7, 0, repeats: Weekday.weekdays)
        a.wakeUpCheck = WakeUpCheckSettings(isEnabled: true, delayMinutes: 5, confirmWindowSeconds: 100)
        var core = T.core([a], lastTick: T.date("2026-11-25 06:59"))
        core.tick(now: T.date("2026-11-25 07:00:00"))
        core.dismiss(now: T.date("2026-11-25 07:01:00"))
        let plan = NotificationPlanner.plan(core: core, now: T.date("2026-11-25 07:01:01"))
        let wake = plan.filter { $0.id.kind == .wake }
        let rering = plan.filter { $0.id.kind == .rering }
        XCTAssertEqual(wake.map(\.fireDate), [T.date("2026-11-25 07:06:00")])
        XCTAssertEqual(rering.first?.fireDate, T.date("2026-11-25 07:07:40"))
        XCTAssertFalse(plan.contains { $0.id.kind == .rering && $0.allowsSnooze })
    }
}

final class SystemAlarmPlanTests: XCTestCase {
    func testPlansNextOccurrencesAndSnoozes() {
        var a = T.alarm(7, 0, repeats: Weekday.weekdays)
        a.voiceID = "cry_hungry"
        var core = T.core([a], lastTick: T.date("2026-11-25 06:59"))
        var plan = SystemAlarmPlanner.plan(core: core, now: T.date("2026-11-25 06:00"))
        XCTAssertEqual(plan.map(\.date), [T.date("2026-11-25 07:00"), T.date("2026-11-26 07:00"), T.date("2026-11-27 07:00")])
        XCTAssertTrue(plan.allSatisfy { $0.soundFile == "cry_hungry.caf" })
        XCTAssertEqual(NotificationID.parse(plan[0].identifier)?.kind, .alarm)

        core.tick(now: T.date("2026-11-25 07:00:00"))
        core.snooze(now: T.date("2026-11-25 07:00:10"))
        plan = SystemAlarmPlanner.plan(core: core, now: T.date("2026-11-25 07:00:11"))
        XCTAssertEqual(plan.first?.date, T.date("2026-11-25 07:05:10"))
        XCTAssertEqual(NotificationID.parse(plan.first!.identifier)?.kind, .snooze)
        XCTAssertFalse(plan.contains { $0.date == T.date("2026-11-25 07:00") })
    }

    func testDisabledAndSkippedAlarmsAreNotHandedToTheSystem() {
        var off = T.alarm(6, 0)
        off.isEnabled = false
        var skip = T.alarm(8, 0, repeats: Weekday.weekdays)
        skip.skippedOccurrence = T.date("2026-11-25 08:00")
        let plan = SystemAlarmPlanner.plan(core: T.core([off, skip], lastTick: T.date("2026-11-25 05:00")),
                                           now: T.date("2026-11-25 05:00"))
        XCTAssertEqual(plan.first?.date, T.date("2026-11-26 08:00"))
        XCTAssertLessThanOrEqual(plan.count, SystemAlarmPlanner.maxItems)
    }
}
