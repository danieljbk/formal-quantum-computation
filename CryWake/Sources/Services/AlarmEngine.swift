import Combine
import Foundation
import UIKit
import UserNotifications

/// Connects the persisted alarms (`AlarmStore`), the timing state machine (`AlarmRuntime`),
/// audio (`CryPlayer`) and local notifications, and exposes what the UI needs to show.
/// All methods are expected to be called on the main thread.
final class AlarmEngine: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    struct RingingSession: Identifiable, Equatable {
        let id = UUID()
        let alarm: Alarm
        let voice: BabyVoice?
        let reason: TriggerReason
        let firstRangAt: Date
        let snoozeCount: Int
        let isTest: Bool

        var canSnooze: Bool { !isTest && alarm.canSnooze(afterSnoozes: snoozeCount) }
    }

    struct WakeCheckPrompt: Equatable {
        let alarm: Alarm
        let deadline: Date
    }

    @Published private(set) var ringing: RingingSession?
    @Published private(set) var wakeCheck: WakeCheckPrompt?
    @Published private(set) var now = Date()
    @Published private(set) var notificationsAllowed = true

    let store: AlarmStore
    let player: CryPlayer
    private let notifier = NotificationScheduler()
    private var runtime = AlarmRuntime()
    private var firstRang: [UUID: Date] = [:]
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(store: AlarmStore, player: CryPlayer = CryPlayer()) {
        self.store = store
        self.player = player
        super.init()
        store.$alarms
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alarms in self?.alarmsChanged(alarms) }
            .store(in: &cancellables)
    }

    func start() {
        UNUserNotificationCenter.current().delegate = self
        notifier.requestAuthorization { [weak self] granted in self?.notificationsAllowed = granted }
        UIApplication.shared.isIdleTimerDisabled = false
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick(Date()) }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick(Date())
    }

    // MARK: Timing

    private func alarmsChanged(_ alarms: [Alarm]) {
        runtime.rearm(alarms, now: Date())
        refreshWakeCheckPrompt()
        rescheduleNotifications()
        player.setKeepAlive(alarms.contains(where: \.isEnabled) || !runtime.triggers.isEmpty)
    }

    func tick(_ date: Date) {
        now = date
        guard ringing == nil else { return }
        if let trigger = runtime.popDue(now: date, alarms: store.alarms),
           let alarm = store.alarm(id: trigger.alarmID) {
            if trigger.reason == .wakeCheck {
                store.updateWakeCheck(alarmID: alarm.id, result: .failed)
                wakeCheck = nil
            }
            ring(alarm, reason: trigger.reason, at: date)
        }
    }

    private func ring(_ alarm: Alarm, reason: TriggerReason, at date: Date, isTest: Bool = false) {
        if reason == .scheduled || firstRang[alarm.id] == nil { firstRang[alarm.id] = date }
        let voice = BabyVoice.voice(id: alarm.voiceID)
        ringing = RingingSession(alarm: alarm, voice: voice, reason: reason,
                                 firstRangAt: firstRang[alarm.id] ?? date,
                                 snoozeCount: runtime.snoozeCount(for: alarm.id), isTest: isTest)
        if let voice {
            player.ring(voice: voice, volume: alarm.volume,
                        fadeIn: alarm.gradualVolume ? alarm.fadeInSeconds : nil, vibrate: alarm.vibrate)
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Rings an alarm immediately so the user can hear and try it.
    func test(_ alarm: Alarm) {
        guard ringing == nil else { return }
        ring(alarm, reason: .scheduled, at: Date(), isTest: true)
    }

    // MARK: User actions while ringing

    func snooze() {
        guard let session = ringing, session.canSnooze else { return }
        runtime.snooze(session.alarm, now: Date())
        endRinging()
    }

    /// Called once the alarm's mission (if any) is complete.
    func soothe() {
        guard let session = ringing else { return }
        let date = Date()
        if session.isTest {
            endRinging()
            return
        }
        let alarm = store.alarm(id: session.alarm.id) ?? session.alarm
        let snoozes = runtime.dismiss(alarm, now: date)
        // A re-ring after a failed wake-up check gets its own record (the failed one stays).
        store.record(WakeRecord(alarmID: alarm.id, alarmLabel: alarm.displayLabel, voiceID: alarm.voiceID,
                                firstRangAt: session.firstRangAt, dismissedAt: date, snoozeCount: snoozes,
                                mission: alarm.mission,
                                wakeCheck: alarm.wakeUpCheck ? .pending : .notRequired))
        firstRang[alarm.id] = nil
        notifier.clearDelivered(alarmID: alarm.id)
        endRinging()
        if !alarm.isRepeating && alarm.isEnabled {
            store.setEnabled(false, id: alarm.id) // triggers alarmsChanged
        } else {
            alarmsChanged(store.alarms)
        }
    }

    func confirmAwake() {
        guard let prompt = wakeCheck else { return }
        runtime.confirmAwake(prompt.alarm.id)
        store.updateWakeCheck(alarmID: prompt.alarm.id, result: .passed)
        wakeCheck = nil
        alarmsChanged(store.alarms)
    }

    private func endRinging() {
        player.stopRinging()
        ringing = nil
        UIApplication.shared.isIdleTimerDisabled = false
        refreshWakeCheckPrompt()
        rescheduleNotifications()
    }

    private func refreshWakeCheckPrompt() {
        if let entry = runtime.wakeChecks.min(by: { $0.value < $1.value }),
           let alarm = store.alarm(id: entry.key) {
            wakeCheck = WakeCheckPrompt(alarm: alarm, deadline: entry.value)
        } else {
            wakeCheck = nil
        }
    }

    // MARK: Notifications

    private func rescheduleNotifications() {
        let plans = NotificationPlanner.plans(triggers: runtime.triggers, alarms: store.alarms,
                                              voices: BabyVoice.catalog, now: Date())
        notifier.apply(plans)
    }

    /// App opened from an alarm notification: ring in-app so the mission still has to be done.
    private func handleNotification(alarmID: UUID) {
        guard ringing == nil, let alarm = store.alarm(id: alarmID) else { return }
        tick(Date())
        if ringing == nil, firstRang[alarm.id] == nil {
            // The trigger was already consumed (e.g. app was suspended); ring anyway.
            ring(alarm, reason: .scheduled, at: Date())
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // In the foreground the app itself is already crying; don't double up.
        DispatchQueue.main.async { self.tick(Date()) }
        completionHandler([])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = NotificationPlanner.alarmID(fromIdentifier: response.notification.request.identifier)
        DispatchQueue.main.async {
            if let id { self.handleNotification(alarmID: id) }
            completionHandler()
        }
    }

    func sceneBecameActive() {
        tick(Date())
        alarmsChanged(store.alarms)
    }
}
