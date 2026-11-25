import Foundation
import Combine

enum WakeCheckResult: String, Codable, Equatable {
    case notRequired, pending, passed, failed
}

/// One finished ringing episode, for the history screen.
struct WakeRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    let alarmID: UUID
    let alarmLabel: String
    let voiceID: String
    let firstRangAt: Date
    let dismissedAt: Date
    let snoozeCount: Int
    let mission: MissionKind
    var wakeCheck: WakeCheckResult

    var secondsToDismiss: TimeInterval { dismissedAt.timeIntervalSince(firstRangAt) }
}

struct WakeStats: Equatable {
    let total: Int
    let averageSnoozes: Double
    let averageMinutesToDismiss: Double
    /// Consecutive most recent wake-ups without a snooze or failed wake-up check.
    let cleanStreak: Int

    init(records: [WakeRecord]) {
        total = records.count
        guard !records.isEmpty else {
            averageSnoozes = 0
            averageMinutesToDismiss = 0
            cleanStreak = 0
            return
        }
        averageSnoozes = Double(records.map(\.snoozeCount).reduce(0, +)) / Double(records.count)
        averageMinutesToDismiss = records.map(\.secondsToDismiss).reduce(0, +) / Double(records.count) / 60
        var streak = 0
        for r in records.sorted(by: { $0.dismissedAt > $1.dismissedAt }) {
            if r.snoozeCount == 0 && r.wakeCheck != .failed { streak += 1 } else { break }
        }
        cleanStreak = streak
    }
}

/// Owns the user's alarms and wake history and persists them as JSON.
final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [Alarm] = []
    @Published private(set) var history: [WakeRecord] = []

    private let fileURL: URL?
    static let historyLimit = 200

    private struct Snapshot: Codable {
        var alarms: [Alarm]
        var history: [WakeRecord]
    }

    static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("CryWake", isDirectory: true).appendingPathComponent("state.json")
    }

    /// - Parameter fileURL: where to persist; `nil` keeps everything in memory (previews/tests).
    init(fileURL: URL? = AlarmStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    var sortedAlarms: [Alarm] {
        alarms.sorted { ($0.hour, $0.minute, $0.id.uuidString) < ($1.hour, $1.minute, $1.id.uuidString) }
    }

    func alarm(id: UUID) -> Alarm? { alarms.first { $0.id == id } }

    func upsert(_ alarm: Alarm) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[i] = alarm
        } else {
            alarms.append(alarm)
        }
        save()
    }

    func delete(id: UUID) {
        alarms.removeAll { $0.id == id }
        save()
    }

    func setEnabled(_ enabled: Bool, id: UUID) {
        guard let i = alarms.firstIndex(where: { $0.id == id }), alarms[i].isEnabled != enabled else { return }
        alarms[i].isEnabled = enabled
        save()
    }

    func record(_ record: WakeRecord) {
        history.insert(record, at: 0)
        if history.count > Self.historyLimit { history.removeLast(history.count - Self.historyLimit) }
        save()
    }

    func updateWakeCheck(alarmID: UUID, result: WakeCheckResult) {
        guard let i = history.firstIndex(where: { $0.alarmID == alarmID && $0.wakeCheck == .pending }) else { return }
        history[i].wakeCheck = result
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    /// The enabled alarm that rings next after `now`, with its date.
    func nextAlarm(after now: Date, calendar: Calendar = .current) -> (alarm: Alarm, date: Date)? {
        alarms.filter(\.isEnabled)
            .compactMap { a in a.nextFireDate(after: now, calendar: calendar).map { (a, $0) } }
            .min { $0.1 < $1.1 }
    }

    var stats: WakeStats { WakeStats(records: history) }

    // MARK: Persistence

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let snap = try? Alarm.makeDecoder().decode(Snapshot.self, from: data) else { return }
        alarms = snap.alarms
        history = snap.history
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try Alarm.makeEncoder().encode(Snapshot(alarms: alarms, history: history))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("CryWake: failed to save state: \(error)")
            #endif
        }
    }
}
