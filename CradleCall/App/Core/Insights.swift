import Foundation

struct InsightsSummary: Equatable {
    var wakeCount: Int
    var onTimeRate: Double
    var averageSecondsToWake: Double
    var averageSnoozes: Double
    var averageMissionSeconds: Double
    var currentStreak: Int
    var bestStreak: Int
    var wakeUpCheckPassRate: Double?
    var averageSleepHours: Double?
    /// Hours short of the goal over the last seven nights (never negative).
    var weeklySleepDebtHours: Double
}

struct DayValue: Identifiable, Equatable {
    var day: Date
    var value: Double
    var id: Date { day }
}

enum InsightsCalculator {
    static func summarize(records: [WakeRecord], sleeps: [SleepSession], sleepGoalHours: Double,
                          now: Date, calendar: Calendar = .current) -> InsightsSummary {
        let count = records.count
        let mean: ([Double]) -> Double = { $0.isEmpty ? 0 : $0.reduce(0, +) / Double($0.count) }
        let checks = records.compactMap(\.passedWakeUpCheck)
        let streaks = onTimeStreaks(records: records, now: now, calendar: calendar)
        let lastWeek = sleepHoursByDay(sleeps: sleeps, days: 7, now: now, calendar: calendar)
        let debt = lastWeek.filter { $0.value > 0 }.reduce(0) { $0 + max(sleepGoalHours - $1.value, 0) }
        let durations = sleeps.compactMap(\.duration).map { $0 / 3600 }
        return InsightsSummary(
            wakeCount: count,
            onTimeRate: count == 0 ? 0 : Double(records.filter(\.isOnTime).count) / Double(count),
            averageSecondsToWake: mean(records.map(\.secondsToWake)),
            averageSnoozes: mean(records.map { Double($0.snoozeCount) }),
            averageMissionSeconds: mean(records.map(\.missionSeconds)),
            currentStreak: streaks.current,
            bestStreak: streaks.best,
            wakeUpCheckPassRate: checks.isEmpty ? nil
                : Double(checks.filter { $0 }.count) / Double(checks.count),
            averageSleepHours: durations.isEmpty ? nil : mean(durations),
            weeklySleepDebtHours: debt)
    }

    /// Consecutive days (ending today or yesterday) on which every wake-up was on time.
    static func onTimeStreaks(records: [WakeRecord], now: Date,
                              calendar: Calendar = .current) -> (current: Int, best: Int) {
        var byDay: [Date: Bool] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.scheduledAt)
            byDay[day] = (byDay[day] ?? true) && record.isOnTime
        }
        let days = byDay.keys.sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in days {
            let consecutive = previous.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } == day
            run = byDay[day] == true ? (consecutive ? run + 1 : 1) : 0
            best = max(best, run)
            previous = day
        }
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard let last = days.last, last == today || last == yesterday else { return (0, best) }
        return (run, best)
    }

    /// Minutes after midnight that the sleeper dismissed the alarm, one point per day.
    static func wakeTimesByDay(records: [WakeRecord], days: Int, now: Date,
                               calendar: Calendar = .current) -> [DayValue] {
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now))
            ?? now
        var earliest: [Date: Date] = [:]
        for record in records where record.dismissedAt >= start {
            let day = calendar.startOfDay(for: record.dismissedAt)
            earliest[day] = min(earliest[day] ?? record.dismissedAt, record.dismissedAt)
        }
        return earliest.map { day, date in
            let comps = calendar.dateComponents([.hour, .minute], from: date)
            return DayValue(day: day, value: Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0)))
        }
        .sorted { $0.day < $1.day }
    }

    /// Hours slept per night, keyed by the day the sleep ended, for the last `days` days.
    static func sleepHoursByDay(sleeps: [SleepSession], days: Int, now: Date,
                                calendar: Calendar = .current) -> [DayValue] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset -> DayValue? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let hours = sleeps.reduce(0.0) { total, session in
                guard let end = session.end, calendar.isDate(end, inSameDayAs: day) else { return total }
                return total + end.timeIntervalSince(session.start) / 3600
            }
            return DayValue(day: day, value: hours)
        }
    }

    static func formatMinutesOfDay(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        var comps = DateComponents()
        comps.hour = total / 60
        comps.minute = total % 60
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total) s" }
        if total < 3600 { return "\(total / 60) min \(total % 60) s" }
        return "\(total / 3600) h \((total % 3600) / 60) min"
    }
}
