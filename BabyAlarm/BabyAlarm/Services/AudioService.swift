import AVFoundation
import AudioToolbox
import Foundation

/// Plays the crying baby (looping, with optional fade-in), voice previews, vibration,
/// and an optional silent keep-alive stream so the app can ring from the background.
final class AudioService {
    static let shared = AudioService()

    private var player: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var vibrationTimer: Timer?
    private var targetVolume: Float = 1

    private let keepAliveEngine = AVAudioEngine()
    private let keepAliveNode = AVAudioPlayerNode()
    private var keepAliveBuffer: AVAudioPCMBuffer?
    private(set) var isKeepAliveRunning = false

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

    var isRinging: Bool { player != nil }

    static func url(for voice: BabyVoice, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: voice.id, withExtension: "caf")
    }

    // MARK: Ringing

    func startRinging(voice: BabyVoice, volume: Double, rampSeconds: Int, vibrate: Bool) {
        stopRinging()
        stopPreview()
        activateSession(mixWithOthers: false)
        guard let url = Self.url(for: voice), let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.numberOfLoops = -1
        targetVolume = Float(min(max(volume, 0.05), 1))
        p.prepareToPlay()
        if rampSeconds > 0 {
            p.volume = targetVolume * 0.08
            p.play()
            p.setVolume(targetVolume, fadeDuration: TimeInterval(rampSeconds))
        } else {
            p.volume = targetVolume
            p.play()
        }
        player = p
        if vibrate {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            let timer = Timer(timeInterval: 1.6, repeats: true) { _ in
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
            RunLoop.main.add(timer, forMode: .common)
            vibrationTimer = timer
        }
    }

    /// Quieter while the user is solving the mission, full volume otherwise.
    func duck(_ ducked: Bool) {
        player?.setVolume(ducked ? targetVolume * 0.3 : targetVolume, fadeDuration: 0.4)
    }

    func stopRinging() {
        player?.stop()
        player = nil
        vibrationTimer?.invalidate()
        vibrationTimer = nil
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

    private func activateSession(mixWithOthers: Bool) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: mixWithOthers ? [.mixWithOthers] : [])
        try? session.setActive(true)
    }
}
