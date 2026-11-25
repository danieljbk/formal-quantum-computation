import AVFoundation
import AudioToolbox
import Foundation

/// Plays the recorded baby cries.
///
/// Three uses share one `AVAudioPlayer`:
/// * **ringing** – loops the chosen cry, optionally fading in, with vibration;
/// * **preview** – plays a cry once from the voice picker;
/// * **keep-alive** – while alarms are armed, loops a cry at zero volume (mixed with other
///   audio) so iOS keeps the app running in the background and the alarm can ring in-app
///   at full length rather than relying only on 30-second notification sounds.
final class CryPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var previewingVoiceID: String?
    @Published private(set) var isRinging = false

    private var player: AVAudioPlayer?
    private var vibrateTimer: Timer?
    private var keepAliveWanted = false
    private var keepAliveActive = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AVAudioSession.sharedInstance())
    }

    // MARK: Keep-alive

    func setKeepAlive(_ wanted: Bool) {
        keepAliveWanted = wanted
        guard !isRinging, previewingVoiceID == nil else { return }
        if wanted { startKeepAlive() } else { stopKeepAlive() }
    }

    private func startKeepAlive() {
        guard !keepAliveActive, let url = BabyVoice.catalog.first?.url() else { return }
        configureSession(mixWithOthers: true)
        if start(url: url, volume: 0, loops: -1) { keepAliveActive = true }
    }

    private func stopKeepAlive() {
        guard keepAliveActive else { return }
        keepAliveActive = false
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func resumeKeepAliveIfWanted() {
        if keepAliveWanted { startKeepAlive() }
    }

    // MARK: Ringing

    func ring(voice: BabyVoice, volume: Double, fadeIn: TimeInterval?, vibrate: Bool) {
        keepAliveActive = false
        previewingVoiceID = nil
        isRinging = true
        configureSession(mixWithOthers: false)
        let target = Float(max(0.05, min(1, volume)))
        if let url = voice.url(), start(url: url, volume: fadeIn == nil ? target : 0.05, loops: -1),
           let fadeIn, fadeIn > 0 {
            player?.setVolume(target, fadeDuration: fadeIn)
        }
        vibrateTimer?.invalidate()
        if vibrate {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            vibrateTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true) { _ in
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }

    func stopRinging() {
        guard isRinging else { return }
        isRinging = false
        vibrateTimer?.invalidate()
        vibrateTimer = nil
        player?.stop()
        player = nil
        resumeKeepAliveIfWanted()
    }

    // MARK: Preview

    func togglePreview(_ voice: BabyVoice) {
        if previewingVoiceID == voice.id { stopPreview(); return }
        guard !isRinging, let url = voice.url() else { return }
        keepAliveActive = false
        configureSession(mixWithOthers: false)
        if start(url: url, volume: 1, loops: 0) { previewingVoiceID = voice.id }
    }

    func stopPreview() {
        guard previewingVoiceID != nil else { return }
        previewingVoiceID = nil
        player?.stop()
        player = nil
        resumeKeepAliveIfWanted()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            if player === self.player, self.previewingVoiceID != nil {
                self.previewingVoiceID = nil
                self.player = nil
                self.resumeKeepAliveIfWanted()
            }
        }
    }

    // MARK: Plumbing

    private func configureSession(mixWithOthers: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: mixWithOthers ? [.mixWithOthers] : [])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("CryWake: audio session error: \(error)")
            #endif
        }
    }

    private func start(url: URL, volume: Float, loops: Int) -> Bool {
        player?.stop()
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return false }
        p.delegate = self
        p.numberOfLoops = loops
        p.volume = volume
        p.prepareToPlay()
        player = p
        return p.play()
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
        DispatchQueue.main.async {
            if self.isRinging || self.keepAliveActive {
                try? AVAudioSession.sharedInstance().setActive(true)
                self.player?.play()
            }
        }
    }
}
