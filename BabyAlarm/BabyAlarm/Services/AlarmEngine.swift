import Foundation
import SwiftUI
import UserNotifications

enum AppEnvironment {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

/// App-facing wrapper around `AlarmEngineCore`: drives the 1 s ticker, persists
/// state, keeps notifications in sync, and turns ringing on and off.
final class AlarmEngine: ObservableObject {
    static let shared = AlarmEngine()

    private(set) var core: AlarmEngineCore
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var keepAliveEnabled: Bool {
        didSet {
            defaults.set(keepAliveEnabled, forKey: Self.keepAliveKey)
            updateKeepAlive()
        }
    }

    private static let keepAliveKey = "babyalarm.keepAlive"
    private let defaults: UserDefaults
    private let repository: AlarmRepository
    private let live: Bool
    private var timer: Timer?
    private var isInBackground = false
    private var started = false

    init(defaults: UserDefaults = .standard, live: Bool = !AppEnvironment.isRunningTests) {
        self.defaults = defaults
        self.live = live
        repository = AlarmRepository(defaults: defaults)
        let now = Date()
        var state = repository.load() ?? AlarmRepository.starterState(now: now)
        state.lastTick = now
        core = AlarmEngineCore(state: state)
        keepAliveEnabled = defaults.object(forKey: Self.keepAliveKey) as? Bool ?? true
    }

    var alarms: [Alarm] { core.alarms }
    var ringing: RingingSession? { core.ringing }
    var wakeCheck: WakeCheckSession? { core.wakeCheck }

    func nextAlarm(after now: Date = Date()) -> (alarm: Alarm, date: Date)? {
        AlarmSchedule.nextAlarm(in: core.alarms, after: now)
    }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        if live {
            NotificationService.shared.engine = self
            NotificationService.shared.requestAuthorization { [weak self] _ in self?.refreshNotificationStatus() }
        }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
        syncNotifications()
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            isInBackground = true
            repository.save(core.state)
        case .active:
            isInBackground = false
            refreshNotificationStatus()
            tick()
            syncNotifications()
        default:
            break
        }
        updateKeepAlive()
    }

    func refreshNotificationStatus() {
        guard live else { return }
        NotificationService.shared.authorizationStatus { [weak self] status in
            self?.notificationStatus = status
        }
    }

    // MARK: Editing

    func save(_ alarm: Alarm) { mutate { $0.upsert(alarm) } }
    func delete(id: UUID) { mutate { $0.delete(id: id) } }
    func setEnabled(_ enabled: Bool, id: UUID) { mutate { $0.setEnabled(enabled, id: id) } }

    @discardableResult
    func addQuickAlarm(minutes: Int, voiceID: String) -> Alarm? {
        var created: Alarm?
        mutate { created = $0.addQuickAlarm(minutes: minutes, voiceID: voiceID, now: Date()) }
        return created
    }

    // MARK: Ringing

    func snooze() { mutate { $0.snooze(now: Date()) } }
    func dismiss() { mutate { $0.dismiss(now: Date()) } }
    func confirmAwake() { mutate { $0.confirmAwake(now: Date()) } }

    func openedFromNotification(_ identifier: String) {
        mutate { $0.handleNotification(identifier: identifier, now: Date()) }
    }

    func snoozeFromNotification(_ identifier: String) {
        mutate { $0.snoozeFromNotification(identifier: identifier, now: Date()) }
    }

    private func tick() {
        mutate { $0.tick(now: Date()) }
    }

    // MARK: Plumbing

    private func mutate(_ body: (inout AlarmEngineCore) -> Void) {
        let before = core
        var next = core
        body(&next)
        let ringingChanged = before.ringing != next.ringing
        let changed = ringingChanged || before.wakeCheck != next.wakeCheck
            || before.state.alarms != next.state.alarms
            || before.state.pending != next.state.pending
            || before.state.handled != next.state.handled
        if changed { objectWillChange.send() }
        core = next
        guard changed else { return }
        repository.save(core.state)
        if ringingChanged { ringingDidChange(from: before.ringing, to: core.ringing) }
        syncNotifications()
        updateKeepAlive()
    }

    private func ringingDidChange(from old: RingingSession?, to new: RingingSession?) {
        guard live else { return }
        if let r = new {
            AudioService.shared.startRinging(voice: r.voice, volume: r.alarm.volume,
                                             rampSeconds: r.alarm.gradualVolumeSeconds, vibrate: r.alarm.vibrate)
            NotificationService.shared.clearDelivered()
        } else {
            AudioService.shared.stopRinging()
            NotificationService.shared.clearDelivered()
        }
    }

    private func syncNotifications() {
        guard live else { return }
        NotificationService.shared.apply(NotificationPlanner.plan(core: core, now: Date()))
    }

    private func updateKeepAlive() {
        guard live else { return }
        let soon = Date().addingTimeInterval(24 * 3600)
        let hasUpcoming = (nextAlarm()?.date).map { $0 < soon } ?? false
        let needed = keepAliveEnabled && isInBackground && core.ringing == nil
            && (hasUpcoming || !core.state.pending.isEmpty || core.wakeCheck != nil)
        if needed {
            AudioService.shared.startKeepAlive()
        } else {
            AudioService.shared.stopKeepAlive()
        }
    }
}
