import AVFoundation
import AudioToolbox
import Foundation

/// Plays the crying baby (looping, fading in, escalating through fussier babies),
/// voice previews, sleep sounds, vibration, and an optional silent keep-alive stream
/// so the app can ring from the background.
final class AudioService {
    static let shared = AudioService()

    private var player: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var sleepPlayer: AVAudioPlayer?
    private var vibrationTimer: Timer?
    private var escalationTimer: Timer?
    private var sleepFadeTimer: Timer?
    private var backupTimer: Timer?
    private var targetVolume: Float = 1
    private var ducked = false
    private var stages: [CryEscalation.Stage] = []
    private var stageIndex = 0
    private var ringStarted = Date()

    private let keepAliveEngine = AVAudioEngine()
    private let keepAliveNode = AVAudioPlayerNode()
    private var keepAliveBuffer: AVAudioPCMBuffer?
    private(set) var isKeepAliveRunning = false

    /// Set while the sleep recorder owns the microphone, so sessions keep `.playAndRecord`.
    var isRecordingSleep = false

    private init() {
        keepAliveEngine.attach(keepAliveNode)
        if let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
           let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100) {
            buffer.frameLength = 44_100
            if let channel = buffer.floatChannelData?[0] {
                channel.update(repeating: 0, count: Int(buffer.frameLength))
            }
            keepAliveEngine.connect(keepAliveNode, to: keepAliveEngine.mainMixerNode, format: format)
            keepAliveBuffer = buffer
        }
    }

    var isRinging: Bool { player != nil || backupTimer != nil }
    private(set) var currentVoice: BabyVoice?

    static func url(for voice: BabyVoice, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: voice.id, withExtension: BabyVoice.fileExtension)
    }

    static func url(for sound: SleepSound, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: sound.id, withExtension: SleepSound.fileExtension)
    }

    // MARK: Ringing

    func startRinging(voice: BabyVoice, volume: Double, rampSeconds: Int, vibrate: Bool, escalate: Bool) {
        stopRinging()
        stopPreview()
        stopSleepSound()
        activateSession(mixWithOthers: false)
        targetVolume = Float(min(max(volume, 0.05), 1))
        ducked = false
        stages = CryEscalation.stages(startingWith: voice, enabled: escalate)
        stageIndex = 0
        ringStarted = Date()

        if !play(stages[0].voice, fadeIn: TimeInterval(rampSeconds)) {
            startBackupSound()
        }
        if stages.count > 1 {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.advanceEscalation() }
            RunLoop.main.add(timer, forMode: .common)
            escalationTimer = timer
        }
        if vibrate {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            let timer = Timer(timeInterval: 1.6, repeats: true) { _ in
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
            RunLoop.main.add(timer, forMode: .common)
            vibrationTimer = timer
        }
    }

    /// Returns false if the clip could not be loaded (the backup sound takes over).
    @discardableResult
    private func play(_ voice: BabyVoice, fadeIn: TimeInterval) -> Bool {
        let url = Self.url(for: voice) ?? Self.url(for: BabyVoiceCatalog.defaultVoice)
        guard let url, let p = try? AVAudioPlayer(contentsOf: url) else { return false }
        p.numberOfLoops = -1
        p.prepareToPlay()
        let level = ducked ? targetVolume * 0.3 : targetVolume
        if fadeIn > 0 {
            p.volume = level * 0.08
            p.play()
            p.setVolume(level, fadeDuration: fadeIn)
        } else {
            p.volume = level
            p.play()
        }
        player?.stop()
        player = p
        currentVoice = voice
        return true
    }

    private func advanceEscalation() {
        let elapsed = Date().timeIntervalSince(ringStarted)
        guard stageIndex + 1 < stages.count, elapsed >= stages[stageIndex + 1].startsAt else { return }
        stageIndex += 1
        play(stages[stageIndex].voice, fadeIn: 1.5)
        if stageIndex + 1 >= stages.count {
            escalationTimer?.invalidate()
            escalationTimer = nil
        }
    }

    /// Last resort if no clip can be played: the system alert sound, repeated.
    private func startBackupSound() {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        let timer = Timer(timeInterval: 2, repeats: true) { _ in AudioServicesPlayAlertSound(SystemSoundID(1005)) }
        RunLoop.main.add(timer, forMode: .common)
        backupTimer = timer
    }

    /// Quieter while the user is solving the mission, full volume otherwise.
    func duck(_ isDucked: Bool) {
        ducked = isDucked
        player?.setVolume(isDucked ? targetVolume * 0.3 : targetVolume, fadeDuration: 0.4)
    }

    func stopRinging() {
        player?.stop()
        player = nil
        currentVoice = nil
        [vibrationTimer, escalationTimer, backupTimer].forEach { $0?.invalidate() }
        vibrationTimer = nil
        escalationTimer = nil
        backupTimer = nil
        if isKeepAliveRunning { activateSession(mixWithOthers: true) }
    }

    // MARK: Previews

    /// Plays a voice once; returns the clip duration.
    @discardableResult
    func preview(_ voice: BabyVoice) -> TimeInterval {
        stopPreview()
        guard !isRinging else { return 0 }
        activateSession(mixWithOthers: false)
        guard let url = Self.url(for: voice), let p = try? AVAudioPlayer(contentsOf: url) else { return 0 }
        p.volume = 0.8
        p.play()
        previewPlayer = p
        return p.duration
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }

    // MARK: Sleep sounds

    private(set) var playingSleepSound: SleepSound?

    /// Loops a sleep sound; with `minutes > 0` it fades out and stops after that long.
    func playSleepSound(_ sound: SleepSound, minutes: Int) {
        stopSleepSound()
        guard !isRinging, let url = Self.url(for: sound), let p = try? AVAudioPlayer(contentsOf: url) else { return }
        activateSession(mixWithOthers: true)
        p.numberOfLoops = -1
        p.volume = 0
        p.play()
        p.setVolume(0.7, fadeDuration: 3)
        sleepPlayer = p
        playingSleepSound = sound
        if minutes > 0 {
            let timer = Timer(timeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                self?.sleepPlayer?.setVolume(0, fadeDuration: 20)
                DispatchQueue.main.asyncAfter(deadline: .now() + 21) { self?.stopSleepSound() }
            }
            RunLoop.main.add(timer, forMode: .common)
            sleepFadeTimer = timer
        }
    }

    func stopSleepSound() {
        sleepFadeTimer?.invalidate()
        sleepFadeTimer = nil
        sleepPlayer?.stop()
        sleepPlayer = nil
        playingSleepSound = nil
    }

    // MARK: Background keep-alive

    /// Streams silence so iOS keeps the app (and its alarm timer) running in the
    /// background; at ring time the real crying starts at full length.
    func startKeepAlive() {
        guard !isKeepAliveRunning, let buffer = keepAliveBuffer else { return }
        activateSession(mixWithOthers: true)
        do {
            try keepAliveEngine.start()
            keepAliveNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            keepAliveNode.play()
            isKeepAliveRunning = true
        } catch {
            isKeepAliveRunning = false
        }
    }

    func stopKeepAlive() {
        guard isKeepAliveRunning else { return }
        keepAliveNode.stop()
        keepAliveEngine.stop()
        isKeepAliveRunning = false
    }

    func activateSession(mixWithOthers: Bool) {
        let session = AVAudioSession.sharedInstance()
        if isRecordingSleep {
            try? session.setCategory(.playAndRecord, mode: .default,
                                     options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
        } else {
            try? session.setCategory(.playback, mode: .default, options: mixWithOthers ? [.mixWithOthers] : [])
        }
        try? session.setActive(true)
    }
}
