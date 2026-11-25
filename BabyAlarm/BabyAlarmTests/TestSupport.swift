import Foundation
@testable import BabyAlarm

enum T {
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }

    /// "2026-11-25 07:00" in UTC (2026-11-25 is a Wednesday).
    static func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = utc
        f.timeZone = utc.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: s.count == 16 ? s + ":00" : s)!
    }

    static func alarm(_ hour: Int, _ minute: Int, repeats: Set<Weekday> = [], mission: MissionSettings = .off) -> Alarm {
        var a = Alarm()
        a.hour = hour
        a.minute = minute
        a.repeatDays = repeats
        a.missions = mission.kind == .none ? [] : [mission]
        return a
    }

    static func core(_ alarms: [Alarm], lastTick: Date) -> AlarmEngineCore {
        var state = EngineState()
        state.alarms = alarms
        state.lastTick = lastTick
        return AlarmEngineCore(state: state, calendar: utc)
    }
}
