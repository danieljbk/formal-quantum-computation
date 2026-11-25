import Foundation

enum TriggerReason: String, Codable, Equatable {
    /// The alarm's regular time.
    case scheduled
    /// A snooze ran out.
    case snooze
    /// The user dismissed the alarm but did not confirm they were awake in time.
    case wakeCheck
}

struct PendingTrigger: Equatable {
    let alarmID: UUID
    let date: Date
    let reason: TriggerReason
}

/// Pure state machine that decides when alarms ring. It holds no timers and does no I/O,
/// so it can be driven by `AlarmEngine` at runtime and by unit tests with fixed dates.
struct AlarmRuntime: Equatable {
    /// How late a trigger may be noticed and still ring (e.g. app resumed from suspension).
    static let defaultGrace: TimeInterval = 10 * 60

    private(set) var scheduled: [UUID: Date] = [:]
    private(set) var snoozes: [UUID: Date] = [:]
    private(set) var wakeChecks: [UUID: Date] = [:]
    private(set) var snoozeCounts: [UUID: Int] = [:]

    /// Recomputes regular fire dates for every enabled alarm and drops pending snoozes or
    /// wake-up checks of alarms that were deleted or switched off.
    mutating func rearm(_ alarms: [Alarm], now: Date, calendar: Calendar = .current) {
        let enabled = alarms.filter(\.isEnabled)
        let live = Set(enabled.map(\.id))
        scheduled = [:]
        for alarm in enabled {
            scheduled[alarm.id] = alarm.nextFireDate(after: now, calendar: calendar)
        }
        let existing = Set(alarms.map(\.id))
        snoozes = snoozes.filter { live.contains($0.key) }
        // A wake-up check outlives the alarm being switched off (one-off alarms switch
        // themselves off when dismissed), but not the alarm being deleted.
        wakeChecks = wakeChecks.filter { existing.contains($0.key) }
        snoozeCounts = snoozeCounts.filter { live.contains($0.key) }
    }

    var triggers: [PendingTrigger] {
        let s = scheduled.map { PendingTrigger(alarmID: $0.key, date: $0.value, reason: .scheduled) }
        let z = snoozes.map { PendingTrigger(alarmID: $0.key, date: $0.value, reason: .snooze) }
        let w = wakeChecks.map { PendingTrigger(alarmID: $0.key, date: $0.value, reason: .wakeCheck) }
        return (s + z + w).sorted { ($0.date, $0.alarmID.uuidString) < ($1.date, $1.alarmID.uuidString) }
    }

    var nextTrigger: PendingTrigger? { triggers.first }

    /// Removes and returns the earliest trigger that is due at `now`. Triggers that are more
    /// than `grace` seconds overdue are consumed silently. A consumed regular trigger of a
    /// repeating alarm is re-armed for its next occurrence.
    mutating func popDue(now: Date, alarms: [Alarm], grace: TimeInterval = AlarmRuntime.defaultGrace,
                         calendar: Calendar = .current) -> PendingTrigger? {
        while let next = nextTrigger, next.date <= now {
            switch next.reason {
            case .scheduled:
                scheduled[next.alarmID] = nil
                if let alarm = alarms.first(where: { $0.id == next.alarmID }), alarm.isRepeating, alarm.isEnabled {
                    scheduled[alarm.id] = alarm.nextFireDate(after: now, calendar: calendar)
                }
                snoozeCounts[next.alarmID] = 0
            case .snooze:
                snoozes[next.alarmID] = nil
            case .wakeCheck:
                wakeChecks[next.alarmID] = nil
            }
            if now.timeIntervalSince(next.date) <= grace {
                return next
            }
        }
        return nil
    }

    func snoozeCount(for id: UUID) -> Int { snoozeCounts[id] ?? 0 }

    /// Registers a snooze. Returns the time the alarm will ring again, or nil if the alarm
    /// does not allow another snooze.
    @discardableResult
    mutating func snooze(_ alarm: Alarm, now: Date) -> Date? {
        let count = snoozeCount(for: alarm.id)
        guard alarm.canSnooze(afterSnoozes: count) else { return nil }
        let at = now.addingTimeInterval(TimeInterval(alarm.snoozeMinutes * 60))
        snoozeCounts[alarm.id] = count + 1
        snoozes[alarm.id] = at
        return at
    }

    /// Ends a ringing episode. Returns how many times it was snoozed. If the alarm has a
    /// wake-up check, a follow-up trigger is armed.
    @discardableResult
    mutating func dismiss(_ alarm: Alarm, now: Date) -> Int {
        let count = snoozeCount(for: alarm.id)
        snoozes[alarm.id] = nil
        snoozeCounts[alarm.id] = nil
        if alarm.wakeUpCheck {
            wakeChecks[alarm.id] = now.addingTimeInterval(TimeInterval(alarm.wakeUpCheckMinutes * 60))
        }
        return count
    }

    mutating func confirmAwake(_ alarmID: UUID) {
        wakeChecks[alarmID] = nil
    }
}
