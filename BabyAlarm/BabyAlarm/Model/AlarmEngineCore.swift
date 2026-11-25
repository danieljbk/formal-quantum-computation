import Foundation

/// Identifies one ring of one alarm (an alarm that repeats has many occurrences).
struct OccurrenceKey: Hashable, Codable {
    let alarmID: UUID
    let epoch: Int

    init(alarmID: UUID, occurrence: Date) {
        self.alarmID = alarmID
        self.epoch = Int(occurrence.timeIntervalSince1970.rounded())
    }

    var occurrence: Date { Date(timeIntervalSince1970: TimeInterval(epoch)) }
    var string: String { "\(alarmID.uuidString)@\(epoch)" }
}

enum PendingEventKind: Codable, Equatable {
    case snooze(count: Int)
    case wakeCheck
}

/// A future event created at runtime (snoozes, wake-up checks), persisted across launches.
struct PendingEvent: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    let key: OccurrenceKey
    let fireDate: Date
    let kind: PendingEventKind
}

struct RingingSession: Equatable {
    let alarm: Alarm
    let key: OccurrenceKey
    let voice: BabyVoice
    let snoozeCount: Int
    let startedAt: Date

    var canSnooze: Bool {
        alarm.snooze.isEnabled && (alarm.snooze.maxCount == 0 || snoozeCount < alarm.snooze.maxCount)
    }

    var snoozesLeftText: String? {
        guard alarm.snooze.isEnabled else { return nil }
        if alarm.snooze.maxCount == 0 { return "Unlimited snoozes" }
        let left = max(0, alarm.snooze.maxCount - snoozeCount)
        return "\(left) snooze\(left == 1 ? "" : "s") left"
    }
}

struct WakeCheckSession: Equatable {
    let alarm: Alarm
    let key: OccurrenceKey
    let deadline: Date
}

struct EngineState: Codable, Equatable {
    var alarms: [Alarm] = []
    var pending: [PendingEvent] = []
    /// Occurrences the user already dismissed, with the time they were handled.
    var handled: [String: Date] = [:]
    var lastTick: Date = Date()
}

/// Pure alarm state machine: no timers, audio or notifications. The app layer
/// calls these methods and reacts to `ringing` / `wakeCheck` changing.
struct AlarmEngineCore {
    var state: EngineState
    private(set) var ringing: RingingSession?
    private(set) var wakeCheck: WakeCheckSession?
    var calendar: Calendar = .current

    /// Alarms older than this are not started late by the in-app ticker
    /// (the notification burst already covered them).
    static let lateRingWindow: TimeInterval = 5 * 60

    init(state: EngineState = EngineState(), calendar: Calendar = .current) {
        self.state = state
        self.calendar = calendar
    }

    var alarms: [Alarm] { state.alarms }

    // MARK: Editing

    mutating func upsert(_ alarm: Alarm) {
        if let i = state.alarms.firstIndex(where: { $0.id == alarm.id }) {
            state.alarms[i] = alarm
        } else {
            state.alarms.append(alarm)
        }
        sortAlarms()
    }

    mutating func delete(id: UUID) {
        state.alarms.removeAll { $0.id == id }
        state.pending.removeAll { $0.key.alarmID == id }
    }

    mutating func setEnabled(_ enabled: Bool, id: UUID) {
        guard let i = state.alarms.firstIndex(where: { $0.id == id }) else { return }
        state.alarms[i].isEnabled = enabled
        if !enabled { state.pending.removeAll { $0.key.alarmID == id } }
    }

    mutating func addQuickAlarm(minutes: Int, voiceID: String, now: Date) -> Alarm {
        var alarm = Alarm()
        let fire = now.addingTimeInterval(TimeInterval(minutes * 60))
        let c = calendar.dateComponents([.hour, .minute], from: fire)
        alarm.hour = c.hour ?? 0
        alarm.minute = c.minute ?? 0
        alarm.oneShotDate = fire
        alarm.voiceID = voiceID
        alarm.label = "Quick alarm · \(minutes) min"
        alarm.mission = .off
        alarm.gradualVolumeSeconds = 0
        upsert(alarm)
        return alarm
    }

    private mutating func sortAlarms() {
        state.alarms.sort { ($0.hour, $0.minute, $0.id.uuidString) < ($1.hour, $1.minute, $1.id.uuidString) }
    }

    // MARK: Time

    func isHandled(_ key: OccurrenceKey) -> Bool { state.handled[key.string] != nil }

    mutating func tick(now: Date) {
        defer { state.lastTick = max(state.lastTick, now) }
        pruneHandled(now: now)
        guard ringing == nil else { return }

        if let check = wakeCheck {
            if now >= check.deadline {
                wakeCheck = nil
                state.pending.removeAll { $0.key == check.key && $0.kind == .wakeCheck }
                startRinging(alarm: check.alarm, key: check.key, snoozeCount: 0, now: now, ignoreHandled: true)
            }
            return
        }

        if let event = state.pending.filter({ $0.fireDate <= now }).min(by: { $0.fireDate < $1.fireDate }) {
            state.pending.removeAll { $0.id == event.id }
            guard let alarm = state.alarms.first(where: { $0.id == event.key.alarmID }) else { return }
            switch event.kind {
            case .snooze(let count):
                startRinging(alarm: alarm, key: event.key, snoozeCount: count, now: now, ignoreHandled: false)
            case .wakeCheck:
                wakeCheck = WakeCheckSession(
                    alarm: alarm, key: event.key,
                    deadline: event.fireDate.addingTimeInterval(TimeInterval(alarm.wakeUpCheck.confirmWindowSeconds)))
            }
            return
        }

        let from = state.lastTick
        let due = state.alarms.compactMap { a -> (Alarm, Date)? in
            guard let d = AlarmSchedule.nextFireDate(for: a, after: from.addingTimeInterval(-1), calendar: calendar),
                  d <= now, now.timeIntervalSince(d) <= Self.lateRingWindow else { return nil }
            return (a, d)
        }.min { $0.1 < $1.1 }
        if let (alarm, date) = due {
            startRinging(alarm: alarm, key: OccurrenceKey(alarmID: alarm.id, occurrence: date),
                         snoozeCount: 0, now: now, ignoreHandled: false)
        }
    }

    /// Called when the user opens the app from one of our notifications.
    mutating func handleNotification(identifier: String, now: Date) {
        guard let parsed = NotificationID.parse(identifier),
              let alarm = state.alarms.first(where: { $0.id == parsed.key.alarmID }) else { return }
        switch parsed.kind {
        case .alarm, .snooze, .rering:
            if let r = ringing, r.key == parsed.key { return }
            guard ringing == nil else { return }
            var count = parsed.kind == .rering ? 0 : parsed.extra
            if let i = state.pending.firstIndex(where: { $0.key == parsed.key && $0.kind != .wakeCheck }) {
                if case .snooze(let c) = state.pending[i].kind { count = c }
                state.pending.remove(at: i)
            }
            if parsed.kind == .rering {
                wakeCheck = nil
                state.pending.removeAll { $0.key == parsed.key }
            }
            startRinging(alarm: alarm, key: parsed.key, snoozeCount: count, now: now,
                         ignoreHandled: parsed.kind == .rering)
        case .wake:
            guard ringing == nil, wakeCheck == nil else { return }
            state.pending.removeAll { $0.key == parsed.key && $0.kind == .wakeCheck }
            wakeCheck = WakeCheckSession(
                alarm: alarm, key: parsed.key,
                deadline: now.addingTimeInterval(TimeInterval(alarm.wakeUpCheck.confirmWindowSeconds)))
        }
    }

    /// Snooze straight from a notification action without opening the app.
    mutating func snoozeFromNotification(identifier: String, now: Date) {
        guard let parsed = NotificationID.parse(identifier),
              let alarm = state.alarms.first(where: { $0.id == parsed.key.alarmID }) else { return }
        var count = parsed.kind == .rering ? 0 : parsed.extra
        if let i = state.pending.firstIndex(where: { $0.key == parsed.key && $0.kind != .wakeCheck }) {
            if case .snooze(let c) = state.pending[i].kind { count = c }
            state.pending.remove(at: i)
        }
        let session = RingingSession(alarm: alarm, key: parsed.key,
                                     voice: BabyVoiceCatalog.resolve(alarm.voiceID, for: parsed.key.occurrence, calendar: calendar),
                                     snoozeCount: count, startedAt: now)
        guard session.canSnooze else { return }
        if ringing?.key == parsed.key { ringing = nil }
        state.pending.append(PendingEvent(key: parsed.key,
                                          fireDate: now.addingTimeInterval(TimeInterval(alarm.snooze.minutes * 60)),
                                          kind: .snooze(count: count + 1)))
    }

    // MARK: Ringing actions

    mutating func snooze(now: Date) {
        guard let r = ringing, r.canSnooze else { return }
        ringing = nil
        state.pending.append(PendingEvent(key: r.key,
                                          fireDate: now.addingTimeInterval(TimeInterval(r.alarm.snooze.minutes * 60)),
                                          kind: .snooze(count: r.snoozeCount + 1)))
    }

    /// Call once the mission (if any) is complete.
    mutating func dismiss(now: Date) {
        guard let r = ringing else { return }
        ringing = nil
        state.handled[r.key.string] = now
        state.pending.removeAll { $0.key == r.key }
        if let live = state.alarms.first(where: { $0.id == r.alarm.id }), live.wakeUpCheck.isEnabled {
            state.pending.append(PendingEvent(key: r.key,
                                              fireDate: now.addingTimeInterval(TimeInterval(live.wakeUpCheck.delayMinutes * 60)),
                                              kind: .wakeCheck))
        } else if r.alarm.oneShotDate != nil {
            delete(id: r.alarm.id)
        }
    }

    mutating func confirmAwake(now: Date) {
        guard let check = wakeCheck else {
            return
        }
        wakeCheck = nil
        state.pending.removeAll { $0.key == check.key }
        if check.alarm.oneShotDate != nil { delete(id: check.alarm.id) }
    }

    private mutating func startRinging(alarm: Alarm, key: OccurrenceKey, snoozeCount: Int, now: Date, ignoreHandled: Bool) {
        guard ringing == nil, ignoreHandled || !isHandled(key) else { return }
        if ignoreHandled { state.handled[key.string] = nil }
        ringing = RingingSession(alarm: alarm, key: key,
                                 voice: BabyVoiceCatalog.resolve(alarm.voiceID, for: key.occurrence, calendar: calendar),
                                 snoozeCount: snoozeCount, startedAt: now)
        // Non-repeating alarms switch themselves off once they ring, like the system Clock app.
        if alarm.repeatDays.isEmpty, alarm.oneShotDate == nil,
           let i = state.alarms.firstIndex(where: { $0.id == alarm.id }) {
            state.alarms[i].isEnabled = false
        }
    }

    private mutating func pruneHandled(now: Date) {
        state.handled = state.handled.filter { now.timeIntervalSince($0.value) < 2 * 24 * 3600 }
    }
}
