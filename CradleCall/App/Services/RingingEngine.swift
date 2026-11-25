import AVFoundation
import AudioToolbox
import MediaPlayer
import UIKit

/// Plays the crying baby: loops the recording, ramps the volume, vibrates and keeps the
/// system volume up while the alarm is active.
@MainActor
final class RingingEngine: ObservableObject {
    @Published private(set) var isRinging = false
    @Published private(set) var currentVolume: Double = 0
    @Published private(set) var isDucked = false

    private var player: AVAudioPlayer?
    private var ramp = VolumeRamp(settings: SoundSettings())
    private var startedAt = Date()
    private var vibrate = true
    private var lockVolume = true
    private var timer: Timer?
    private var lastVibration = Date.distantPast
    private let systemVolume = SystemVolume()
    private var volumeObservation: NSKeyValueObservation?

    func start(url: URL, sound: SoundSettings, lockVolume: Bool) {
        stop()
        ramp = VolumeRamp(settings: sound)
        vibrate = sound.vibrate
        self.lockVolume = lockVolume
        startedAt = Date()
        do {
            let session = AVAudioSession.sharedInstance()
            // Playback ignores the Ring/Silent switch; no mixing so the cry is front and centre.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Float(ramp.volume(at: 0))
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            print("CradleCall: could not play cry: \(error)")
        }
        isRinging = true
        isDucked = false
        if lockVolume { systemVolume.set(max(ramp.target, 0.75)) }
        observeSystemVolume()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Quietens the cry while the sleeper is working on a mission.
    func duck() {
        guard isRinging else { return }
        isDucked = true
        player?.volume = Float(min(ramp.target, 0.12))
    }

    /// Back to full crying, e.g. after the sleeper stops interacting with the mission.
    func restore() {
        guard isRinging else { return }
        isDucked = false
        startedAt = Date().addingTimeInterval(-ramp.duration)
        player?.volume = Float(ramp.target)
        if lockVolume { systemVolume.set(max(ramp.target, 0.75)) }
    }

    /// Pass `deactivateSession: false` when another component (the background keep-alive)
    /// takes over the audio session.
    func stop(deactivateSession: Bool = true) {
        let wasRinging = isRinging || player != nil
        timer?.invalidate()
        timer = nil
        volumeObservation = nil
        player?.stop()
        player = nil
        isRinging = false
        isDucked = false
        currentVolume = 0
        if wasRinging, deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func tick() {
        guard isRinging else { return }
        if !isDucked {
            let volume = ramp.volume(at: Date().timeIntervalSince(startedAt))
            player?.volume = Float(volume)
            currentVolume = volume
        }
        if vibrate, !isDucked, Date().timeIntervalSince(lastVibration) > 1.6 {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            lastVibration = Date()
        }
        if player?.isPlaying == false { player?.play() }
    }

    /// Anti-cheat: if the sleeper turns the volume down, turn it back up.
    private func observeSystemVolume() {
        guard lockVolume else { return }
        volumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) {
            [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor in
                guard let self, self.isRinging, !self.isDucked else { return }
                let floor = max(self.ramp.target, 0.75)
                if Double(value) < floor - 0.01 { self.systemVolume.set(floor) }
            }
        }
    }
}

/// Sets the device's output volume through a hidden `MPVolumeView` slider.
@MainActor
final class SystemVolume {
    private let volumeView: MPVolumeView = {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.alpha = 0.01
        view.isUserInteractionEnabled = false
        return view
    }()

    func set(_ value: Double) {
        if volumeView.superview == nil, let window = Self.keyWindow {
            window.addSubview(volumeView)
        }
        let slider = volumeView.subviews.compactMap { $0 as? UISlider }.first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            slider?.setValue(Float(value), animated: false)
            slider?.sendActions(for: .valueChanged)
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

/// Keeps the app running in the background (by playing silence) so the in-app alarm can
/// ring at full volume even when AlarmKit is unavailable.
@MainActor
final class BackgroundKeepAlive {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var configured = false
    private(set) var isRunning = false

    func start() {
        guard !isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if !configured {
                engine.attach(node)
                let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!
                engine.connect(node, to: engine.mainMixerNode, format: format)
                configured = true
            }
            let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!
            guard let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 22_050) else { return }
            silence.frameLength = silence.frameCapacity // zero-filled
            try engine.start()
            node.scheduleBuffer(silence, at: nil, options: .loops)
            node.play()
            isRunning = true
        } catch {
            print("CradleCall: keep-alive failed: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }
        node.stop()
        engine.stop()
        isRunning = false
    }
}
