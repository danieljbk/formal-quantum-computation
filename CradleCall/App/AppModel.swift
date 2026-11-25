import Foundation
import Observation
import SwiftUI
import UIKit

/// An alarm that is currently crying.
struct RingSession: Identifiable, Equatable {
    enum Reason: Equatable { case scheduled, snoozeEnded, wakeUpCheckFailed, preview }

    let id = UUID()
    var alarm: WakeAlarm
    var scheduledAt: Date
    var startedAt: Date
    var snoozeCount: Int
    var reason: Reason
    var missionStartedAt: Date?
}

/// Full-screen flows that take over the app.
enum Overlay: String, Identifiable {
    case ringing, wakeUpCheck, briefing
    var id: String { rawValue }
}

/// Owns the app state and drives ringing, missions, wake-up checks and scheduling.
@MainActor
@Observable
final class AppModel {
    private(set) var state: PersistedState
    var overlay: Overlay?
    private(set) var currentRing: RingSession?
    private(set) var now = Date()
    private(set) var alarmKitSupported = false
    private(set) var alarmKitAuthorized = false
    private(set) var notificationsAuthorized = false

    let engine = RingingEngine()
    let notifications = NotificationService()
    private let keepAlive = BackgroundKeepAlive()
    private let persists: Bool
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var lastRung: [UUID: Date] = [:]
    @ObservationIgnored private var pendingSnooze: (session: RingSession, at: Date)?
    @ObservationIgnored private var lastDeadmanPush = Date.distantPast
    @ObservationIgnored private var isInForeground = true
    @ObservationIgnored private var rescheduleTask: Task<Void, Never>?
    @ObservationIgnored private var alertObservation: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var started = false

    init(state: PersistedState? = nil, persists: Bool = true) {
        self.persists = persists
        self.state = state ?? PersistenceController.load()
    }

    // MARK: - Derived state

    var alarms: [WakeAlarm] { state.alarms }
    var settings: AppSettings { state.settings }
    var customVoices: [BabyVoice] { state.customVoices }
    var allVoices: [BabyVoice] { VoiceLibrary.allVoices(custom: state.customVoices) }
    var activeSleep: SleepSession? { state.sleeps.last { $0.end == nil } }
    var pendingWakeUpCheck: WakeUpCheckPlan? { state.pendingWakeUpCheck }
    var snoozedUntil: Date? { pendingSnooze?.at }

    var nextRing: (alarm: WakeAlarm, date: Date)? {
        AlarmSchedule.nextRing(in: state.alarms, after: now)
    }

    func voice(id: String) -> BabyVoice { VoiceLibrary.voice(id: id, custom: state.customVoices) }

    // MARK: - Lifecycle

    func start() async {
        guard !started else { return }
        started = true
        notifications.registerCategories()
        notificationsAuthorized = await notifications.requestAuthorization()
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            alarmKitSupported = true
            alarmKitAuthorized = await AlarmKitService.requestAuthorization()
            alertObservation = AlarmKitService.observeAlerts { [weak self] alarmID in
                self?.handleSystemAlert(alarmID: alarmID)
            }
        }
        #endif
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .cradleCallMissionRequested, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleLaunchRequest() }
        })
        observers.append(center.addObserver(forName: UIApplication.significantTimeChangeNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.requestReschedule() }
        })
        startTicker()
        requestReschedule()
        handleLaunchRequest()
        tick()
    }

    func refreshAuthorization() async {
        notificationsAuthorized = await notifications.authorizationStatus() == .authorized
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            alarmKitAuthorized = AlarmKitService.isAuthorized
        }
        #endif
    }

    func requestAlarmKitAccess() async {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            alarmKitAuthorized = await AlarmKitService.requestAuthorization()
            requestReschedule()
        }
        #endif
    }

    func requestNotificationAccess() async {
        notificationsAuthorized = await notifications.requestAuthorization()
        requestReschedule()
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isInForeground = true
            if !engine.isRinging { keepAlive.stop() }
            Task {
                await refreshAuthorization()
                requestReschedule()
            }
            handleLaunchRequest()
            tick()
        case .background:
            isInForeground = false
            if shouldKeepAlive { keepAlive.start() }
        default:
            break
        }
    }

    func appWillTerminate() {
        guard state.alarms.contains(where: \.isEnabled) else { return }
        notifications.warnAppClosed()
    }

    /// Background keep-alive is only needed when AlarmKit is not ringing for us.
    private var shouldKeepAlive: Bool {
        !alarmKitAuthorized && settings.antiCheat.keepAliveInBackground
            && (state.alarms.contains(where: \.isEnabled) || pendingSnooze != nil
                || state.pendingWakeUpCheck != nil)
            && !engine.isRinging
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        now = Date()
        checkDueAlarms()
        checkSnooze()
        checkWakeUpCheck()
        pushDeadman()
    }

    // MARK: - Editing

    func update(reschedule: Bool = true, _ mutate: (inout PersistedState) -> Void) {
        mutate(&state)
        if persists { PersistenceController.save(state) }
        if reschedule { requestReschedule() }
    }

    func upsert(_ alarm: WakeAlarm) {
        update { state in
            if let index = state.alarms.firstIndex(where: { $0.id == alarm.id }) {
                state.alarms[index] = alarm
            } else {
                state.alarms.append(alarm)
            }
            state.alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        }
    }

    func deleteAlarm(_ id: UUID) {
        update { $0.alarms.removeAll { $0.id == id } }
    }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        update { state in
            guard let index = state.alarms.firstIndex(where: { $0.id == id }) else { return }
            state.alarms[index].isEnabled = enabled
            state.alarms[index].skippedOccurrence = nil
        }
    }

    func skipNext(_ id: UUID) {
        guard let alarm = state.alarms.first(where: { $0.id == id }),
              let next = AlarmSchedule.nextFireDate(for: alarm, after: Date()) else { return }
        update { state in
            guard let index = state.alarms.firstIndex(where: { $0.id == id }) else { return }
            state.alarms[index].skippedOccurrence = next
        }
    }

    func clearSkip(_ id: UUID) {
        update { state in
            guard let index = state.alarms.firstIndex(where: { $0.id == id }) else { return }
            state.alarms[index].skippedOccurrence = nil
        }
    }

    /// A one-off alarm `minutes` from now.
    func addQuickAlarm(minutes: Int, template: WakeAlarm? = nil) {
        let date = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        var alarm = template ?? WakeAlarm(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
        alarm.id = UUID()
        alarm.hour = comps.hour ?? 0
        alarm.minute = comps.minute ?? 0
        alarm.label = "Quick alarm · \(minutes) min"
        alarm.repeatDays = []
        alarm.isEnabled = true
        alarm.oneShotDate = date
        upsert(alarm)
    }

    func newAlarmTemplate() -> WakeAlarm {
        var alarm = WakeAlarm(hour: 7, minute: 0)
        if !settings.antiCheat.requireMission { alarm.missions = [] }
        return alarm
    }

    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        update { mutate(&$0.settings) }
    }

    // MARK: - Voices

    func addCustomVoice(_ voice: BabyVoice) {
        update(reschedule: false) { $0.customVoices.append(voice) }
    }

    func renameCustomVoice(_ id: String, to name: String) {
        update(reschedule: false) { state in
            guard let index = state.customVoices.firstIndex(where: { $0.id == id }) else { return }
            state.customVoices[index].name = name
        }
    }

    func deleteCustomVoice(_ voice: BabyVoice) {
        VoiceLibrary.delete(voice)
        update { state in
            state.customVoices.removeAll { $0.id == voice.id }
            for index in state.alarms.indices where state.alarms[index].voiceID == voice.id {
                state.alarms[index].voiceID = BabyVoice.defaultID
            }
        }
    }

    // MARK: - Sleep

    func startSleep(source: SleepSession.Source = .manual) {
        guard activeSleep == nil else { return }
        update(reschedule: false) { $0.sleeps.append(SleepSession(start: Date(), source: source)) }
    }

    func endSleep(at date: Date = Date()) {
        update(reschedule: false) { state in
            guard let index = state.sleeps.lastIndex(where: { $0.end == nil }) else { return }
            state.sleeps[index].end = max(date, state.sleeps[index].start)
        }
    }

    func rateSleep(_ id: UUID, rating: Int) {
        update(reschedule: false) { state in
            guard let index = state.sleeps.firstIndex(where: { $0.id == id }) else { return }
            state.sleeps[index].rating = rating
        }
    }

    func deleteSleep(_ id: UUID) {
        update(reschedule: false) { $0.sleeps.removeAll { $0.id == id } }
    }

    func addSleep(start: Date, end: Date) {
        guard end > start else { return }
        update(reschedule: false) { $0.sleeps.append(SleepSession(start: start, end: end, source: .manual)) }
    }

    func clearHistory() {
        update(reschedule: false) { $0.history.removeAll() }
    }

    // MARK: - Ringing

    /// Rings an alarm right now so the user can hear the voice and try the missions.
    func preview(_ alarm: WakeAlarm) {
        startRinging(RingSession(alarm: alarm, scheduledAt: Date(), startedAt: Date(), snoozeCount: 0,
                                 reason: .preview))
    }

    /// Entry point for alarm notifications, AlarmKit alerts and the "Soothe baby" intent.
    func ringFromExternal(alarmID: UUID, scheduledAt: Date? = nil, tag: String? = nil) {
        if currentRing != nil { return }
        if let snooze = pendingSnooze, snooze.session.alarm.id == alarmID,
           tag == nil || tag?.hasPrefix("snooze-") == true {
            resumeSnooze()
            return
        }
        if let plan = state.pendingWakeUpCheck, plan.alarmID == alarmID,
           tag?.hasPrefix("wakecheck-") == true || plan.phase(at: Date()) == .failed {
            failWakeUpCheck(plan, forceRing: true)
            return
        }
        guard let alarm = state.alarms.first(where: { $0.id == alarmID }) else { return }
        let fire = scheduledAt ?? AlarmSchedule.nextFireDate(for: alarm, after: Date().addingTimeInterval(-600))
            ?? Date()
        lastRung[alarmID] = fire
        startRinging(RingSession(alarm: alarm, scheduledAt: min(fire, Date()), startedAt: Date(),
                                 snoozeCount: 0, reason: .scheduled))
    }

    private func handleSystemAlert(alarmID: UUID) {
        guard isInForeground else { return }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { AlarmKitService.stopAlerting() }
        #endif
        ringFromExternal(alarmID: alarmID)
    }

    private func handleLaunchRequest() {
        guard let id = LaunchRouter.takePendingMission() else { return }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { AlarmKitService.stopAlerting() }
        #endif
        ringFromExternal(alarmID: id)
    }

    private func checkDueAlarms() {
        // With AlarmKit the system rings for us; otherwise ring from the (kept-alive) app.
        guard !alarmKitAuthorized, currentRing == nil else { return }
        for alarm in state.alarms where alarm.isEnabled {
            guard let fire = AlarmSchedule.nextFireDate(for: alarm, after: now.addingTimeInterval(-60)),
                  fire <= now, lastRung[alarm.id] != fire else { continue }
            lastRung[alarm.id] = fire
            startRinging(RingSession(alarm: alarm, scheduledAt: fire, startedAt: Date(), snoozeCount: 0,
                                     reason: .scheduled))
            return
        }
    }

    private func startRinging(_ session: RingSession) {
        guard currentRing == nil else { return }
        keepAlive.stop()
        engine.start(url: VoiceLibrary.playableURL(id: session.alarm.voiceID, custom: state.customVoices),
                     sound: session.alarm.sound, lockVolume: settings.antiCheat.lockVolume)
        currentRing = session
        overlay = .ringing
        lastDeadmanPush = .distantPast
        pushDeadman()
    }

    /// While the app is ringing under AlarmKit, keep a system alarm armed a little in the
    /// future so force-quitting the app mid-mission only brings the crying back.
    private func pushDeadman() {
        guard alarmKitAuthorized, let ring = currentRing, ring.reason != .preview,
              Date().timeIntervalSince(lastDeadmanPush) >= 30 else { return }
        lastDeadmanPush = Date()
        let alarm = ring.alarm
        Task { await scheduleFollowUp(alarm: alarm, tag: FollowUpTag.deadman(alarm.id),
                                      at: Date().addingTimeInterval(90)) }
    }

    func canSnooze() -> Bool {
        guard let ring = currentRing else { return false }
        return SnoozePolicy.canSnooze(ring.alarm.snooze, used: ring.snoozeCount)
    }

    func snooze() {
        guard var ring = currentRing, canSnooze() else { return }
        ring.snoozeCount += 1
        let at = Date().addingTimeInterval(TimeInterval(ring.alarm.snooze.minutes * 60))
        currentRing = nil
        overlay = nil
        silenceEngine()
        guard ring.reason != .preview else { return }
        pendingSnooze = (ring, at)
        let alarm = ring.alarm
        let scheduledAt = ring.scheduledAt
        cancelFollowUp(tag: FollowUpTag.deadman(alarm.id))
        Task {
            await notifications.cancelChain(alarmID: alarm.id, scheduledAt: scheduledAt)
            await scheduleFollowUp(alarm: alarm, tag: FollowUpTag.snooze(alarm.id), at: at)
        }
    }

    private func checkSnooze() {
        guard let snooze = pendingSnooze, currentRing == nil, now >= snooze.at else { return }
        // Under AlarmKit the system alarm rings; we take over when the app is in front.
        if alarmKitAuthorized && !isInForeground { return }
        resumeSnooze()
    }

    private func resumeSnooze() {
        guard let snooze = pendingSnooze else { return }
        pendingSnooze = nil
        var session = snooze.session
        session.startedAt = Date()
        session.reason = .snoozeEnded
        session.missionStartedAt = nil
        startRinging(session)
    }

    /// The sleeper is working on a mission: quieten the cry.
    func missionActivity() {
        guard var ring = currentRing else { return }
        if ring.missionStartedAt == nil {
            ring.missionStartedAt = Date()
            currentRing = ring
        }
        engine.duck()
    }

    /// The sleeper went idle mid-mission: full volume again.
    func missionWentIdle() {
        engine.restore()
    }

    func completeMission(usedEmergencyExit: Bool = false) {
        guard let ring = currentRing else { return }
        let finished = Date()
        currentRing = nil
        silenceEngine()
        guard ring.reason != .preview else {
            overlay = nil
            return
        }
        pendingSnooze = nil
        let alarm = ring.alarm
        for tag in FollowUpTag.all(for: alarm.id) { cancelFollowUp(tag: tag) }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { AlarmKitService.stopAlerting() }
        #endif
        let plan = alarm.wakeUpCheck.isEnabled
            ? WakeUpCheckPlan(alarmID: alarm.id, dismissedAt: finished, settings: alarm.wakeUpCheck)
            : nil
        let record = WakeRecord(
            alarmID: alarm.id, alarmLabel: alarm.label, voiceID: alarm.voiceID,
            scheduledAt: ring.scheduledAt, ringStartedAt: ring.startedAt, dismissedAt: finished,
            snoozeCount: ring.snoozeCount, missions: alarm.missions.map(\.kind),
            missionSeconds: ring.missionStartedAt.map { finished.timeIntervalSince($0) } ?? 0,
            usedEmergencyExit: usedEmergencyExit, passedWakeUpCheck: nil)
        update { state in
            if ring.reason == .wakeUpCheckFailed,
               let index = state.history.lastIndex(where: { $0.alarmID == alarm.id }) {
                state.history[index].passedWakeUpCheck = false
            } else {
                state.history.append(record)
            }
            if let index = state.sleeps.lastIndex(where: { $0.end == nil }) {
                state.sleeps[index].end = finished
            }
            if let index = state.alarms.firstIndex(where: { $0.id == alarm.id }) {
                if state.alarms[index].oneShotDate != nil {
                    state.alarms.remove(at: index)
                } else if !state.alarms[index].isRepeating {
                    state.alarms[index].isEnabled = false
                } else if let skipped = state.alarms[index].skippedOccurrence, skipped < finished {
                    state.alarms[index].skippedOccurrence = nil
                }
            }
            state.pendingWakeUpCheck = plan
        }
        let scheduledAt = ring.scheduledAt
        Task {
            await notifications.cancelChain(alarmID: alarm.id, scheduledAt: scheduledAt)
            if let plan {
                await notifications.scheduleWakeUpCheckPrompt(plan, label: alarm.label)
                await scheduleFollowUp(alarm: alarm, tag: FollowUpTag.wakeCheck(alarm.id), at: plan.deadline)
            }
        }
        overlay = alarm.showsBriefing ? .briefing : nil
    }

    private func silenceEngine() {
        if !isInForeground && shouldKeepAliveAfterRing {
            keepAlive.start()
            engine.stop(deactivateSession: false)
        } else {
            engine.stop()
        }
    }

    private var shouldKeepAliveAfterRing: Bool {
        !alarmKitAuthorized && settings.antiCheat.keepAliveInBackground
    }

    // MARK: - Wake-up check

    private func checkWakeUpCheck() {
        guard let plan = state.pendingWakeUpCheck, currentRing == nil else { return }
        switch plan.phase(at: now) {
        case .waiting:
            break
        case .prompting:
            if isInForeground, overlay == nil { overlay = .wakeUpCheck }
        case .failed:
            failWakeUpCheck(plan, forceRing: false)
        }
    }

    func confirmAwake() {
        guard let plan = state.pendingWakeUpCheck else {
            if overlay == .wakeUpCheck { overlay = nil }
            return
        }
        cancelFollowUp(tag: FollowUpTag.wakeCheck(plan.alarmID))
        notifications.cancelWakeUpCheckPrompt()
        update(reschedule: false) { state in
            state.pendingWakeUpCheck = nil
            if let index = state.history.lastIndex(where: { $0.alarmID == plan.alarmID }) {
                state.history[index].passedWakeUpCheck = true
            }
        }
        if overlay == .wakeUpCheck { overlay = nil }
    }

    private func failWakeUpCheck(_ plan: WakeUpCheckPlan, forceRing: Bool) {
        notifications.cancelWakeUpCheckPrompt()
        update(reschedule: false) { state in
            state.pendingWakeUpCheck = nil
            if let index = state.history.lastIndex(where: { $0.alarmID == plan.alarmID }) {
                state.history[index].passedWakeUpCheck = false
            }
        }
        if overlay == .wakeUpCheck { overlay = nil }
        // Under AlarmKit a system alarm is already set for the deadline; ring here only if
        // we are in front or are the only thing that can ring.
        guard forceRing || !alarmKitAuthorized || isInForeground,
              let alarm = state.alarms.first(where: { $0.id == plan.alarmID }) else { return }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), isInForeground { AlarmKitService.stopAlerting() }
        #endif
        startRinging(RingSession(alarm: alarm, scheduledAt: plan.deadline, startedAt: Date(), snoozeCount: 0,
                                 reason: .wakeUpCheckFailed))
    }

    // MARK: - Scheduling

    func requestReschedule() {
        rescheduleTask?.cancel()
        rescheduleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.rescheduleAll()
        }
    }

    private func rescheduleAll() async {
        let custom = state.customVoices
        let sound: (WakeAlarm) -> String = { VoiceLibrary.soundFileName(for: $0.voiceID, custom: custom) }
        await notifications.scheduleBedtimeReminder(settings: settings)
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), alarmKitAuthorized {
            await AlarmKitService.sync(alarms: state.alarms, soundFile: sound)
            await notifications.scheduleAlarmChains(alarms: [], soundFile: sound, antiCheat: settings.antiCheat)
            return
        }
        #endif
        await notifications.scheduleAlarmChains(alarms: state.alarms, soundFile: sound,
                                                 antiCheat: settings.antiCheat)
    }

    private func scheduleFollowUp(alarm: WakeAlarm, tag: String, at date: Date) async {
        let sound = VoiceLibrary.soundFileName(for: alarm.voiceID, custom: state.customVoices)
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), alarmKitAuthorized {
            await AlarmKitService.scheduleFollowUp(alarm: alarm, tag: tag, at: date, sound: sound)
            return
        }
        #endif
        await notifications.scheduleFollowUp(alarm: alarm, tag: tag, at: date, sound: sound,
                                             count: settings.antiCheat.backupRingCount + 1,
                                             spacing: settings.antiCheat.backupRingSpacing)
    }

    private func cancelFollowUp(tag: String) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { AlarmKitService.cancelFollowUp(tag: tag) }
        #endif
        notifications.cancelFollowUp(tag: tag)
    }
}
