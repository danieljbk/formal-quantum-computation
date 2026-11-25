import Foundation

enum NotificationKind: String {
    case alarm, snooze, wake, rering
}

/// Notification identifiers: "<kind>.<alarm uuid>.<occurrence epoch>.<burst index>.<extra>".
struct NotificationID: Equatable {
    let kind: NotificationKind
    let key: OccurrenceKey
    let index: Int
    /// Snooze count for `.snooze`, 0 otherwise.
    let extra: Int

    var string: String { "\(kind.rawValue).\(key.alarmID.uuidString).\(key.epoch).\(index).\(extra)" }

    static func parse(_ s: String) -> NotificationID? {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              let kind = NotificationKind(rawValue: parts[0]),
              let uuid = UUID(uuidString: parts[1]),
              let epoch = Int(parts[2]), let index = Int(parts[3]), let extra = Int(parts[4]) else { return nil }
        return NotificationID(kind: kind,
                              key: OccurrenceKey(alarmID: uuid, occurrence: Date(timeIntervalSince1970: TimeInterval(epoch))),
                              index: index, extra: extra)
    }
}

struct PlannedNotification: Equatable {
    let id: NotificationID
    let fireDate: Date
    let soundFile: String
    let title: String
    let body: String
    let allowsSnooze: Bool
}

/// Decides which local notifications should be pending right now.
///
/// iOS cannot ring a third-party alarm indefinitely from the background, so each
/// ring is backed by a burst of notifications spaced by the clip length (≤ 30 s),
/// which keeps the baby crying until the user opens the app. iOS allows at most
/// 64 pending notifications per app, so the plan is capped and rebuilt whenever
/// anything changes.
enum NotificationPlanner {
    static let defaultBudget = 60
    static let defaultBurstCount = 8
    static let defaultSpacing: TimeInterval = 30
    static let occurrencesPerAlarm = 4

    static func plan(core: AlarmEngineCore, now: Date,
                     budget: Int = defaultBudget,
                     burstCount: Int = defaultBurstCount,
                     spacing: TimeInterval = defaultSpacing) -> [PlannedNotification] {
        let calendar = core.calendar
        var items: [PlannedNotification] = []
        let burstSpan = spacing * TimeInterval(max(burstCount - 1, 0))

        func burst(_ kind: NotificationKind, alarm: Alarm, key: OccurrenceKey, start: Date, extra: Int, allowsSnooze: Bool) {
            let voice = BabyVoiceCatalog.resolve(alarm.voiceID, for: key.occurrence, calendar: calendar)
            for i in 0..<burstCount {
                let fire = start.addingTimeInterval(spacing * TimeInterval(i))
                guard fire > now else { continue }
                items.append(PlannedNotification(
                    id: NotificationID(kind: kind, key: key, index: i, extra: extra),
                    fireDate: fire,
                    soundFile: voice.fileName,
                    title: i == 0 ? "👶 \(alarm.displayLabel)" : "👶 The baby is still crying!",
                    body: i == 0 ? "\(voice.displayName) is crying. Open to wake up." : "Open the app to calm the baby and stop the alarm.",
                    allowsSnooze: allowsSnooze))
            }
        }

        for alarm in core.alarms where alarm.isEnabled {
            let dates = AlarmSchedule.upcomingFireDates(for: alarm, after: now.addingTimeInterval(-burstSpan - 1),
                                                        count: occurrencesPerAlarm, calendar: calendar)
            for date in dates {
                let key = OccurrenceKey(alarmID: alarm.id, occurrence: date)
                if core.isHandled(key) || core.ringing?.key == key { continue }
                if core.state.pending.contains(where: { $0.key == key }) { continue }
                burst(.alarm, alarm: alarm, key: key, start: date, extra: 0, allowsSnooze: alarm.snooze.isEnabled)
            }
        }

        for event in core.state.pending {
            guard let alarm = core.alarms.first(where: { $0.id == event.key.alarmID }) else { continue }
            switch event.kind {
            case .snooze(let count):
                let left = alarm.snooze.maxCount == 0 || count < alarm.snooze.maxCount
                burst(.snooze, alarm: alarm, key: event.key, start: event.fireDate, extra: count,
                      allowsSnooze: alarm.snooze.isEnabled && left)
            case .wakeCheck:
                let voice = BabyVoiceCatalog.resolve(alarm.voiceID, for: event.key.occurrence, calendar: calendar)
                if event.fireDate > now {
                    items.append(PlannedNotification(
                        id: NotificationID(kind: .wake, key: event.key, index: 0, extra: 0),
                        fireDate: event.fireDate, soundFile: voice.fileName,
                        title: "Are you awake?",
                        body: "Tap within \(alarm.wakeUpCheck.confirmWindowSeconds) s or the baby starts crying again.",
                        allowsSnooze: false))
                }
                let reRing = event.fireDate.addingTimeInterval(TimeInterval(alarm.wakeUpCheck.confirmWindowSeconds))
                burst(.rering, alarm: alarm, key: event.key, start: reRing, extra: 0, allowsSnooze: false)
            }
        }

        // Keep the current ring backed by notifications so it survives the app being killed.
        if let r = core.ringing {
            burst(.alarm, alarm: r.alarm, key: r.key, start: r.startedAt, extra: r.snoozeCount,
                  allowsSnooze: r.canSnooze)
        }

        if let check = core.wakeCheck, let alarm = core.alarms.first(where: { $0.id == check.alarm.id }) {
            burst(.rering, alarm: alarm, key: check.key, start: check.deadline, extra: 0, allowsSnooze: false)
        }

        items.sort { ($0.fireDate, $0.id.string) < ($1.fireDate, $1.id.string) }
        return Array(items.prefix(budget))
    }
}
