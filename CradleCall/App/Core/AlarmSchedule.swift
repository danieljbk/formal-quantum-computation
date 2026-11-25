import Foundation

/// Pure calendar arithmetic for working out when alarms ring.
enum AlarmSchedule {
    /// The first time strictly after `date` at which `alarm` rings, or `nil` if it never will.
    static func nextFireDate(for alarm: WakeAlarm, after date: Date, calendar: Calendar = .current) -> Date? {
        upcomingFireDates(for: alarm, after: date, count: 1, calendar: calendar).first
    }

    /// The next `count` ring times strictly after `date`.
    static func upcomingFireDates(for alarm: WakeAlarm, after date: Date, count: Int,
                                  calendar: Calendar = .current) -> [Date] {
        guard alarm.isEnabled, count > 0 else { return [] }
        if let oneShot = alarm.oneShotDate {
            return oneShot > date ? [oneShot] : []
        }
        var results: [Date] = []
        let startOfDay = calendar.startOfDay(for: date)
        // Enough days to find `count` occurrences even with a single repeat day.
        let horizon = alarm.isRepeating ? 7 * count + 1 : 2
        for offset in 0...horizon {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfDay),
                  let candidate = calendar.date(bySettingHour: alarm.hour, minute: alarm.minute,
                                                second: 0, of: day),
                  candidate > date else { continue }
            if alarm.isRepeating {
                guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: candidate)),
                      alarm.repeatDays.contains(weekday) else { continue }
            }
            if let skipped = alarm.skippedOccurrence, abs(skipped.timeIntervalSince(candidate)) < 1 {
                continue
            }
            results.append(candidate)
            if !alarm.isRepeating || results.count == count { break }
        }
        return results
    }

    /// The soonest ring among `alarms`.
    static func nextRing(in alarms: [WakeAlarm], after date: Date,
                         calendar: Calendar = .current) -> (alarm: WakeAlarm, date: Date)? {
        alarms.compactMap { alarm in
            nextFireDate(for: alarm, after: date, calendar: calendar).map { (alarm, $0) }
        }
        .min { $0.1 < $1.1 }
    }

    /// "Rings in 7 h 12 min" style text.
    static func countdownText(from now: Date, to date: Date) -> String {
        let minutes = max(0, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
        let days = minutes / (24 * 60)
        let hours = (minutes % (24 * 60)) / 60
        let mins = minutes % 60
        if days > 0 { return "Rings in \(days) d \(hours) h" }
        if hours > 0 { return "Rings in \(hours) h \(mins) min" }
        return "Rings in \(mins) min"
    }
}
