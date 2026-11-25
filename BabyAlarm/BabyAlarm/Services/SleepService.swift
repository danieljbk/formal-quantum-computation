import AVFoundation
import Foundation
import UserNotifications

/// Sleep tab: sleep sounds, bedtime reminder, and the overnight sound recorder
/// that finds snoring / talking events.
final class SleepService: ObservableObject {
    static let shared = SleepService()

    @Published private(set) var sessions: [SleepSession] = []
    @Published private(set) var active: SleepSession?
    @Published private(set) var currentLevel: Double = -160
    @Published private(set) var playingSoundID: String?
    @Published var settings: SleepSettings {
        didSet {
            saveSettings()
            scheduleBedtimeReminder()
        }
    }

    private let defaults: UserDefaults
    private let settingsKey = "babyalarm.sleepSettings.v1"
    private let sessionsKey = "babyalarm.sleepSessions.v1"
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var detector = SoundEventDetector()
    private var playback: AVAudioPlayer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: settingsKey), let s = try? JSONDecoder().decode(SleepSettings.self, from: data) {
            settings = s
        } else {
            settings = SleepSettings()
        }
        if let data = defaults.data(forKey: sessionsKey), let list = try? JSONDecoder().decode([SleepSession].self, from: data) {
            sessions = list.filter { !$0.isActive }
        }
    }

    static var recordingsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Sleep", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Sounds

    func toggleSound(_ sound: SleepSound) {
        if playingSoundID == sound.id {
            AudioService.shared.stopSleepSound()
            playingSoundID = nil
        } else {
            AudioService.shared.playSleepSound(sound, minutes: settings.soundTimerMinutes)
            playingSoundID = AudioService.shared.playingSleepSound?.id
        }
    }

    func refreshPlayingSound() {
        playingSoundID = AudioService.shared.playingSleepSound?.id
    }

    // MARK: Tracking

    static func requestMicrophone(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { ok in DispatchQueue.main.async { completion(ok) } }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { ok in DispatchQueue.main.async { completion(ok) } }
        }
    }

    func startSleep() {
        guard active == nil else { return }
        var session = SleepSession(start: Date())
        session.soundID = playingSoundID
        active = session
        detector = SoundEventDetector()
        guard settings.recordSounds else { return }
        Self.requestMicrophone { [weak self] granted in
            guard let self, granted, self.active?.id == session.id else { return }
            self.beginRecording(for: session)
        }
    }

    private func beginRecording(for session: SleepSession) {
        AudioService.shared.isRecordingSleep = true
        AudioService.shared.activateSession(mixWithOthers: true)
        let file = "\(session.id.uuidString).m4a"
        let url = Self.recordingsDirectory.appendingPathComponent(file)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 24_000,
        ]
        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else {
            AudioService.shared.isRecordingSleep = false
            return
        }
        rec.isMeteringEnabled = true
        guard rec.record() else {
            AudioService.shared.isRecordingSleep = false
            return
        }
        recorder = rec
        active?.recordingFile = file
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.sampleLevel() }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func sampleLevel() {
        guard let rec = recorder else { return }
        rec.updateMeters()
        let level = Double(rec.averagePower(forChannel: 0))
        currentLevel = level
        detector.ingest(level: level, at: rec.currentTime)
    }

    /// Ends tonight's session (also called automatically when an alarm starts ringing).
    func finishSleep() {
        guard var session = active else { return }
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        AudioService.shared.isRecordingSleep = false
        detector.finish()
        session.end = Date()
        session.events = detector.events
        active = nil
        currentLevel = -160
        if session.duration >= 60 {
            sessions.append(session)
            sessions.sort { $0.start > $1.start }
            if sessions.count > 120 { deleteSession(sessions[sessions.count - 1]) }
        } else if let file = session.recordingFile {
            try? FileManager.default.removeItem(at: Self.recordingsDirectory.appendingPathComponent(file))
        }
        saveSessions()
    }

    func deleteSession(_ session: SleepSession) {
        if let file = session.recordingFile {
            try? FileManager.default.removeItem(at: Self.recordingsDirectory.appendingPathComponent(file))
        }
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }

    /// Plays the part of last night's recording where an event happened.
    func play(_ event: SoundEvent, in session: SleepSession) {
        playback?.stop()
        guard let file = session.recordingFile,
              let p = try? AVAudioPlayer(contentsOf: Self.recordingsDirectory.appendingPathComponent(file)) else { return }
        AudioService.shared.activateSession(mixWithOthers: false)
        p.currentTime = max(0, event.offset - 1)
        p.play()
        playback = p
        let length = min(event.duration + 2, 30)
        DispatchQueue.main.asyncAfter(deadline: .now() + length) { [weak self] in
            if self?.playback === p { p.stop() }
        }
    }

    // MARK: Bedtime reminder

    static let bedtimeIdentifier = "bedtime.reminder"

    func scheduleBedtimeReminder() {
        guard !AppEnvironment.isRunningTests else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.bedtimeIdentifier])
        guard settings.bedtimeReminderEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "🌙 Time to wind down"
        content.body = "Put the phone on charge, start a sleep sound, and the baby will wake you in the morning."
        content.sound = .default
        var comps = DateComponents()
        comps.hour = settings.bedtimeHour
        comps.minute = settings.bedtimeMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: Self.bedtimeIdentifier, content: content, trigger: trigger))
    }

    // MARK: Persistence

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: settingsKey) }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) { defaults.set(data, forKey: sessionsKey) }
    }
}
