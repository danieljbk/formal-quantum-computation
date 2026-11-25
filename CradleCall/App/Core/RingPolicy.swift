import Foundation

/// Volume curve for a ringing alarm.
struct VolumeRamp: Equatable {
    var target: Double
    var start: Double
    var duration: TimeInterval

    init(settings: SoundSettings) {
        target = min(max(settings.volume, 0.05), 1)
        if settings.gradualIncrease {
            start = min(0.1, target)
            duration = max(settings.rampSeconds, 1)
        } else {
            start = target
            duration = 0
        }
    }

    func volume(at elapsed: TimeInterval) -> Double {
        guard duration > 0, elapsed < duration else { return target }
        let progress = max(elapsed, 0) / duration
        // Ease-in so the cry stays soft at first and then builds quickly.
        return start + (target - start) * progress * progress
    }
}

/// Settings that stop the sleeper from cheating their way back to bed.
struct AntiCheatSettings: Codable, Hashable {
    /// Push the system volume back up while the baby is crying.
    var lockVolume: Bool = true
    /// Restart the current mission and restore full volume after this many idle seconds.
    var inactivityResetSeconds: Int = 20
    /// Number of follow-up crying notifications scheduled after each ring.
    var backupRingCount: Int = 12
    /// Seconds between follow-up crying notifications.
    var backupRingSpacing: Int = 30
    /// Keep the app alive in the background so it can ring at full volume.
    var keepAliveInBackground: Bool = true
    /// Times the emergency phrase must be typed to give up on a mission.
    var emergencyPhraseRepeats: Int = 3
    /// New alarms must have at least one mission.
    var requireMission: Bool = true
}

enum SnoozePolicy {
    static func canSnooze(_ settings: SnoozeSettings, used: Int) -> Bool {
        guard settings.isEnabled else { return false }
        return settings.maxCount == 0 || used < settings.maxCount
    }

    static func remaining(_ settings: SnoozeSettings, used: Int) -> Int? {
        guard settings.isEnabled else { return 0 }
        guard settings.maxCount > 0 else { return nil }
        return max(settings.maxCount - used, 0)
    }
}

/// Resets a mission when the sleeper stops interacting with it.
struct InactivityGuard {
    let timeout: TimeInterval
    private(set) var lastInteraction: Date

    init(timeout: TimeInterval, now: Date) {
        self.timeout = timeout
        lastInteraction = now
    }

    mutating func noteInteraction(at date: Date) { lastInteraction = date }

    func isExpired(at date: Date) -> Bool {
        timeout > 0 && date.timeIntervalSince(lastInteraction) >= timeout
    }

    func secondsRemaining(at date: Date) -> Int {
        max(0, Int((timeout - date.timeIntervalSince(lastInteraction)).rounded(.up)))
    }
}

/// Times for the follow-up check after an alarm is dismissed.
struct WakeUpCheckPlan: Codable, Hashable {
    var alarmID: UUID
    var promptAt: Date
    var deadline: Date

    init(alarmID: UUID, dismissedAt: Date, settings: WakeUpCheckSettings) {
        self.alarmID = alarmID
        promptAt = dismissedAt.addingTimeInterval(TimeInterval(settings.delayMinutes * 60))
        deadline = promptAt.addingTimeInterval(TimeInterval(settings.responseSeconds))
    }

    enum Phase: Equatable { case waiting, prompting, failed }

    func phase(at date: Date) -> Phase {
        if date < promptAt { return .waiting }
        if date < deadline { return .prompting }
        return .failed
    }
}

/// Spacing for crying notifications that back up the in-app alarm.
enum BackupRingPlan {
    static func dates(startingAt first: Date, count: Int, spacing: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (0..<count).map { first.addingTimeInterval(TimeInterval($0 * max(spacing, 1))) }
    }

    /// iOS keeps at most 64 pending notifications. Shares what is left between alarms.
    static func perOccurrenceBudget(alarmOccurrences: Int, reserved: Int, requested: Int,
                                    systemLimit: Int = 64) -> Int {
        guard alarmOccurrences > 0 else { return 0 }
        let available = max(systemLimit - reserved, 0)
        return max(1, min(requested, available / alarmOccurrences))
    }
}
