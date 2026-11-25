import Foundation

enum AlarmSchedule {
    /// The first instant strictly after `date` at which `alarm` rings, or nil if it never will.
    static func nextFireDate(for alarm: Alarm, after date: Date, calendar: Calendar = .current) -> Date? {
        guard alarm.isEnabled else { return nil }
        if let shot = alarm.oneShotDate {
            return shot > date ? shot : nil
        }
        if alarm.repeatDays.isEmpty {
            var comps = DateComponents()
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            comps.second = 0
            return calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
        }
        return alarm.repeatDays.compactMap { day -> Date? in
            var comps = DateComponents()
            comps.weekday = day.rawValue
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            comps.second = 0
            return calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
        }.min()
    }

    /// Up to `count` consecutive fire dates after `date`.
    static func upcomingFireDates(for alarm: Alarm, after date: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        var cursor = date
        while result.count < count, let next = nextFireDate(for: alarm, after: cursor, calendar: calendar) {
            result.append(next)
            if alarm.oneShotDate != nil || alarm.repeatDays.isEmpty { break }
            cursor = next
        }
        return result
    }

    static func nextAlarm(in alarms: [Alarm], after date: Date, calendar: Calendar = .current) -> (alarm: Alarm, date: Date)? {
        alarms.compactMap { a in nextFireDate(for: a, after: date, calendar: calendar).map { (a, $0) } }
            .min { $0.1 < $1.1 }
            .map { (alarm: $0.0, date: $0.1) }
    }

    static func countdownText(from now: Date, to target: Date) -> String {
        let total = max(0, Int(target.timeIntervalSince(now).rounded(.up)))
        let minutes = (total + 59) / 60
        let days = minutes / (24 * 60)
        let hours = (minutes % (24 * 60)) / 60
        let mins = minutes % 60
        if days > 0 { return "Rings in \(days) d \(hours) h" }
        if hours > 0 { return "Rings in \(hours) h \(mins) min" }
        if mins <= 1 { return "Rings in less than a minute" }
        return "Rings in \(mins) min"
    }

    static func repeatSummary(_ days: Set<Weekday>) -> String {
        if days.isEmpty { return "Once" }
        if days.count == 7 { return "Every day" }
        if days == Weekday.weekdays { return "Weekdays" }
        if days == Weekday.weekend { return "Weekends" }
        return Weekday.displayOrder.filter { days.contains($0) }.map(\.shortName).joined(separator: ", ")
    }

    static func timeText(hour: Int, minute: Int, calendar: Calendar = .current) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = calendar.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.calendar = calendar
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}
