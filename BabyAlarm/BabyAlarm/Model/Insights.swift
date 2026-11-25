import Foundation

/// One morning: when the alarm rang and how the user woke up.
struct WakeRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    let alarmID: UUID
    let label: String
    let voiceID: String
    /// The scheduled occurrence.
    let scheduled: Date
    /// When the ring (or the last snooze ring) started.
    let rangAt: Date
    let dismissedAt: Date
    let snoozeCount: Int
    let missionKinds: [MissionKind]
    /// nil = no wake-up check, true = confirmed, false = missed (baby cried again).
    var wakeCheckPassed: Bool?

    /// Minutes from the scheduled time until the alarm was finally dismissed.
    var minutesToGetUp: Double { max(0, dismissedAt.timeIntervalSince(scheduled) / 60) }

    /// A "clean" morning: little snoozing and no missed wake-up check.
    var isOnTime: Bool { snoozeCount <= 1 && wakeCheckPassed != false }
}

struct InsightsSummary: Equatable {
    var currentStreak: Int
    var bestStreak: Int
    var averageMinutesToGetUp: Double?
    var averageSnoozes: Double?
    var onTimeRate: Double?
    var mornings: Int
}

struct DailyPoint: Equatable, Identifiable {
    let day: Date
    let value: Double
    var id: Date { day }
}

enum Insights {
    /// Streak of consecutive calendar days (ending today or yesterday) with an on-time wake-up.
    static func summary(records: [WakeRecord], now: Date, calendar: Calendar = .current) -> InsightsSummary {
        let byDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.scheduled) }
        let goodDays = Set(byDay.filter { $0.value.allSatisfy(\.isOnTime) }.keys)

        func streak(endingAt start: Date) -> Int {
            var n = 0
            var day = start
            while goodDays.contains(day) {
                n += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            }
            return n
        }

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let current = goodDays.contains(today) ? streak(endingAt: today) : streak(endingAt: yesterday)

        var best = 0
        for day in goodDays {
            let prev = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            if !goodDays.contains(prev) { best = max(best, streak(endingAt: forwardEnd(from: day, in: goodDays, calendar: calendar))) }
        }

        let n = Double(records.count)
        return InsightsSummary(
            currentStreak: current,
            bestStreak: max(best, current),
            averageMinutesToGetUp: records.isEmpty ? nil : records.map(\.minutesToGetUp).reduce(0, +) / n,
            averageSnoozes: records.isEmpty ? nil : Double(records.map(\.snoozeCount).reduce(0, +)) / n,
            onTimeRate: records.isEmpty ? nil : Double(records.filter(\.isOnTime).count) / n,
            mornings: records.count)
    }

    private static func forwardEnd(from day: Date, in days: Set<Date>, calendar: Calendar) -> Date {
        var end = day
        while let next = calendar.date(byAdding: .day, value: 1, to: end), days.contains(next) { end = next }
        return end
    }

    /// Minutes-to-get-up per day for the last `days` days (days without a record are omitted).
    static func wakeSeries(records: [WakeRecord], days: Int, now: Date, calendar: Calendar = .current) -> [DailyPoint] {
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
        let byDay = Dictionary(grouping: records.filter { $0.scheduled >= start }) { calendar.startOfDay(for: $0.scheduled) }
        return byDay.map { day, recs in
            DailyPoint(day: day, value: recs.map(\.minutesToGetUp).reduce(0, +) / Double(recs.count))
        }.sorted { $0.day < $1.day }
    }

    /// Hours slept per night (by the day the session ended) for the last `days` days.
    static func sleepSeries(sessions: [SleepSession], days: Int, now: Date, calendar: Calendar = .current) -> [DailyPoint] {
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
        let finished = sessions.compactMap { s -> (Date, Double)? in
            guard let end = s.end, end >= start else { return nil }
            return (calendar.startOfDay(for: end), s.duration / 3600)
        }
        let byDay = Dictionary(grouping: finished, by: \.0)
        return byDay.map { DailyPoint(day: $0.key, value: $0.value.map(\.1).reduce(0, +)) }.sorted { $0.day < $1.day }
    }
}
