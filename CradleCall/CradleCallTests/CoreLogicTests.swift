import XCTest
@testable import CradleCall

final class AlarmScheduleTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testOneTimeAlarmRingsTodayWhenStillAhead() {
        let alarm = WakeAlarm(hour: 7, minute: 30)
        let now = date(2026, 11, 25, 6, 0) // Wednesday
        XCTAssertEqual(AlarmSchedule.nextFireDate(for: alarm, after: now, calendar: calendar),
                       date(2026, 11, 25, 7, 30))
    }

    func testOneTimeAlarmRollsToTomorrow() {
        let alarm = WakeAlarm(hour: 7, minute: 30)
        let now = date(2026, 11, 25, 8, 0)
        XCTAssertEqual(AlarmSchedule.nextFireDate(for: alarm, after: now, calendar: calendar),
                       date(2026, 11, 26, 7, 30))
    }

    func testWeekdayAlarmSkipsWeekend() {
        var alarm = WakeAlarm(hour: 7, minute: 0)
        alarm.repeatDays = Weekday.weekdays
        let fridayEvening = date(2026, 11, 27, 20, 0)
        XCTAssertEqual(AlarmSchedule.nextFireDate(for: alarm, after: fridayEvening, calendar: calendar),
                       date(2026, 11, 30, 7, 0)) // Monday
    }

    func testUpcomingDatesForSingleRepeatDay() {
        var alarm = WakeAlarm(hour: 9, minute: 15)
        alarm.repeatDays = [.sunday]
        let dates = AlarmSchedule.upcomingFireDates(for: alarm, after: date(2026, 11, 25, 0, 0), count: 2,
                                                    calendar: calendar)
        XCTAssertEqual(dates, [date(2026, 11, 29, 9, 15), date(2026, 12, 6, 9, 15)])
    }

    func testSkippedOccurrenceIsSkipped() {
        var alarm = WakeAlarm(hour: 7, minute: 0)
        alarm.repeatDays = Set(Weekday.allCases)
        alarm.skippedOccurrence = date(2026, 11, 26, 7, 0)
        XCTAssertEqual(AlarmSchedule.nextFireDate(for: alarm, after: date(2026, 11, 25, 8, 0), calendar: calendar),
                       date(2026, 11, 27, 7, 0))
    }

    func testDisabledAndExpiredQuickAlarmsNeverRing() {
        var disabled = WakeAlarm(hour: 7, minute: 0)
        disabled.isEnabled = false
        XCTAssertNil(AlarmSchedule.nextFireDate(for: disabled, after: Date(), calendar: calendar))

        var quick = WakeAlarm(hour: 7, minute: 0)
        quick.oneShotDate = date(2026, 11, 25, 7, 5)
        XCTAssertEqual(AlarmSchedule.nextFireDate(for: quick, after: date(2026, 11, 25, 7, 0), calendar: calendar),
                       date(2026, 11, 25, 7, 5))
        XCTAssertNil(AlarmSchedule.nextFireDate(for: quick, after: date(2026, 11, 25, 7, 6), calendar: calendar))
    }

    func testNextRingPicksSoonest() {
        var late = WakeAlarm(hour: 9, minute: 0)
        late.label = "late"
        var early = WakeAlarm(hour: 6, minute: 0)
        early.label = "early"
        let next = AlarmSchedule.nextRing(in: [late, early], after: date(2026, 11, 25, 5, 0), calendar: calendar)
        XCTAssertEqual(next?.alarm.label, "early")
    }

    func testCountdownText() {
        let now = date(2026, 11, 25, 0, 0)
        XCTAssertEqual(AlarmSchedule.countdownText(from: now, to: now.addingTimeInterval(7 * 3600 + 12 * 60)),
                       "Rings in 7 h 12 min")
        XCTAssertEqual(AlarmSchedule.countdownText(from: now, to: now.addingTimeInterval(90)), "Rings in 2 min")
    }
}

final class MissionLogicTests: XCTestCase {
    func testMathProblemsAreDeterministicAndCorrect() {
        for difficulty in MissionDifficulty.allCases {
            var a = SplitMix64(seed: 42)
            var b = SplitMix64(seed: 42)
            for _ in 0..<50 {
                let p = MathProblemGenerator.make(difficulty, using: &a)
                XCTAssertEqual(p, MathProblemGenerator.make(difficulty, using: &b))
                XCTAssertEqual(evaluate(p.text), p.answer, p.text)
            }
        }
    }

    /// Evaluates the generator's tiny expression language independently.
    private func evaluate(_ text: String) -> Int {
        let normalized = text.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "−", with: "-")
        let expression = NSExpression(format: normalized)
        return (expression.expressionValue(with: nil, context: nil) as? NSNumber)?.intValue ?? .min
    }

    func testTypingMatchingRespectsDifficulty() {
        XCTAssertTrue(TypingPhrases.matches("  i am awake ", target: "I am awake", difficulty: .easy))
        XCTAssertFalse(TypingPhrases.matches("i am awake", target: "I am awake.", difficulty: .hard))
        XCTAssertTrue(TypingPhrases.matches("I am awake.", target: "I am awake.", difficulty: .extreme))
    }

    func testTypingPhraseLengthGrowsWithDifficulty() {
        var rng = SplitMix64(seed: 7)
        let easy = TypingPhrases.pick(.easy, using: &rng)
        XCTAssertLessThanOrEqual(easy.split(separator: " ").count, 4)
        var rng2 = SplitMix64(seed: 7)
        let extreme = TypingPhrases.pick(.extreme, using: &rng2)
        XCTAssertGreaterThan(extreme.count, easy.count)
    }

    func testMemoryBoard() {
        var rng = SplitMix64(seed: 1)
        var board = MemoryBoard.make(.medium, using: &rng)
        XCTAssertEqual(board.side, 4)
        XCTAssertEqual(board.pattern.count, 5)
        let miss = (0..<board.cellCount).first { !board.pattern.contains($0) }!
        let missResult = board.tap(miss)
        XCTAssertEqual(missResult, .miss)
        let cells = board.pattern.sorted()
        for cell in cells.dropLast() {
            let result = board.tap(cell)
            XCTAssertEqual(result, .hit)
        }
        let repeated = board.tap(cells[0])
        XCTAssertEqual(repeated, .alreadyFound)
        let last = board.tap(cells[cells.count - 1])
        XCTAssertEqual(last, .complete)
        XCTAssertTrue(board.isComplete)
    }

    func testShakeCounterUsesHysteresis() {
        var counter = ShakeCounter(difficulty: .medium)
        // Staying above the threshold counts once.
        counter.add(magnitude: 2.5, at: 0)
        counter.add(magnitude: 2.6, at: 0.2)
        XCTAssertEqual(counter.count, 1)
        // Dropping back down re-arms it.
        counter.add(magnitude: 1.0, at: 0.3)
        counter.add(magnitude: 2.2, at: 0.5)
        XCTAssertEqual(counter.count, 2)
        // Too gentle for medium difficulty.
        counter.add(magnitude: 1.0, at: 0.6)
        counter.add(magnitude: 1.8, at: 0.8)
        XCTAssertEqual(counter.count, 2)
    }

    func testStepDetector() {
        var detector = StepDetector()
        var t = 0.0
        for _ in 0..<10 {
            detector.add(magnitude: 1.25, at: t)
            detector.add(magnitude: 0.95, at: t + 0.2)
            t += 0.5
        }
        XCTAssertEqual(detector.steps, 10)
    }

    func testBarcodeMissionNeedsRegisteredCode() {
        XCTAssertFalse(MissionConfig(kind: .barcode).isReady)
        XCTAssertTrue(MissionConfig(kind: .barcode, barcodeValue: "4006381333931").isReady)
        XCTAssertTrue(MissionConfig(kind: .math).isReady)
    }
}

final class RingPolicyTests: XCTestCase {
    func testVolumeRampEasesUpToTarget() {
        var sound = SoundSettings()
        sound.volume = 0.8
        sound.rampSeconds = 40
        let ramp = VolumeRamp(settings: sound)
        XCTAssertEqual(ramp.volume(at: 0), 0.1, accuracy: 0.0001)
        XCTAssertLessThan(ramp.volume(at: 10), ramp.volume(at: 30))
        XCTAssertEqual(ramp.volume(at: 40), 0.8, accuracy: 0.0001)
        XCTAssertEqual(ramp.volume(at: 400), 0.8, accuracy: 0.0001)
        sound.gradualIncrease = false
        XCTAssertEqual(VolumeRamp(settings: sound).volume(at: 0), 0.8, accuracy: 0.0001)
    }

    func testSnoozeLimits() {
        var snooze = SnoozeSettings()
        snooze.maxCount = 2
        XCTAssertTrue(SnoozePolicy.canSnooze(snooze, used: 1))
        XCTAssertFalse(SnoozePolicy.canSnooze(snooze, used: 2))
        XCTAssertEqual(SnoozePolicy.remaining(snooze, used: 1), 1)
        snooze.maxCount = 0
        XCTAssertTrue(SnoozePolicy.canSnooze(snooze, used: 99))
        XCTAssertNil(SnoozePolicy.remaining(snooze, used: 99))
        snooze.isEnabled = false
        XCTAssertFalse(SnoozePolicy.canSnooze(snooze, used: 0))
    }

    func testInactivityGuard() {
        let start = Date()
        var guardState = InactivityGuard(timeout: 20, now: start)
        XCTAssertFalse(guardState.isExpired(at: start.addingTimeInterval(19)))
        XCTAssertTrue(guardState.isExpired(at: start.addingTimeInterval(20)))
        guardState.noteInteraction(at: start.addingTimeInterval(15))
        XCTAssertFalse(guardState.isExpired(at: start.addingTimeInterval(30)))
        XCTAssertEqual(guardState.secondsRemaining(at: start.addingTimeInterval(30)), 5)
    }

    func testWakeUpCheckPlanPhases() {
        var settings = WakeUpCheckSettings()
        settings.delayMinutes = 5
        settings.responseSeconds = 100
        let dismissed = Date(timeIntervalSince1970: 1_000_000)
        let plan = WakeUpCheckPlan(alarmID: UUID(), dismissedAt: dismissed, settings: settings)
        XCTAssertEqual(plan.phase(at: dismissed.addingTimeInterval(60)), .waiting)
        XCTAssertEqual(plan.phase(at: dismissed.addingTimeInterval(301)), .prompting)
        XCTAssertEqual(plan.phase(at: dismissed.addingTimeInterval(400)), .failed)
    }

    func testBackupRingBudgetRespectsSystemLimit() {
        XCTAssertEqual(BackupRingPlan.perOccurrenceBudget(alarmOccurrences: 2, reserved: 4, requested: 13), 13)
        XCTAssertEqual(BackupRingPlan.perOccurrenceBudget(alarmOccurrences: 10, reserved: 4, requested: 13), 6)
        XCTAssertEqual(BackupRingPlan.perOccurrenceBudget(alarmOccurrences: 100, reserved: 4, requested: 13), 1)
        let dates = BackupRingPlan.dates(startingAt: Date(timeIntervalSince1970: 0), count: 3, spacing: 30)
        XCTAssertEqual(dates.map(\.timeIntervalSince1970), [0, 30, 60])
    }
}

final class InsightsTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func record(day: Int, lateMinutes: Double, snoozes: Int = 0) -> WakeRecord {
        let scheduled = calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 7))!
        return WakeRecord(alarmID: UUID(), alarmLabel: "Wake", voiceID: BabyVoice.defaultID,
                          scheduledAt: scheduled, ringStartedAt: scheduled,
                          dismissedAt: scheduled.addingTimeInterval(lateMinutes * 60),
                          snoozeCount: snoozes, missions: [.math], missionSeconds: 30)
    }

    func testStreaksAndRates() {
        let records = [record(day: 20, lateMinutes: 2), record(day: 21, lateMinutes: 20, snoozes: 2),
                       record(day: 22, lateMinutes: 1), record(day: 23, lateMinutes: 3),
                       record(day: 24, lateMinutes: 4)]
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
        let summary = InsightsCalculator.summarize(records: records, sleeps: [], sleepGoalHours: 8, now: now,
                                                   calendar: calendar)
        XCTAssertEqual(summary.wakeCount, 5)
        XCTAssertEqual(summary.currentStreak, 3)
        XCTAssertEqual(summary.bestStreak, 3)
        XCTAssertEqual(summary.onTimeRate, 0.8, accuracy: 0.0001)
        XCTAssertEqual(summary.averageSnoozes, 0.4, accuracy: 0.0001)
        XCTAssertNil(summary.averageSleepHours)
    }

    func testStreakBreaksAfterMissedDays() {
        let records = [record(day: 20, lateMinutes: 1)]
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
        XCTAssertEqual(InsightsCalculator.onTimeStreaks(records: records, now: now, calendar: calendar).current, 0)
    }

    func testSleepHoursAndDebt() {
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 7))!
        let sleep = SleepSession(start: end.addingTimeInterval(-6 * 3600), end: end)
        let days = InsightsCalculator.sleepHoursByDay(sleeps: [sleep], days: 7, now: end, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.last?.value ?? 0, 6, accuracy: 0.0001)
        let summary = InsightsCalculator.summarize(records: [], sleeps: [sleep], sleepGoalHours: 8, now: end,
                                                   calendar: calendar)
        XCTAssertEqual(summary.weeklySleepDebtHours, 2, accuracy: 0.0001)
        XCTAssertEqual(summary.averageSleepHours ?? 0, 6, accuracy: 0.0001)
    }

    func testWakeTimesByDay() {
        let records = [record(day: 23, lateMinutes: 10), record(day: 24, lateMinutes: 0)]
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
        let points = InsightsCalculator.wakeTimesByDay(records: records, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(points.map(\.value), [7 * 60 + 10, 7 * 60])
    }
}
