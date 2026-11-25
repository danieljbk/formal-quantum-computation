import AVFoundation
import Foundation

/// Locates baby-cry recordings and manages the user's own recordings.
enum VoiceLibrary {
    /// `Library/Sounds`: iOS looks here (and in the app bundle) for notification and alarm sounds.
    static var soundsDirectory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("Sounds", isDirectory: true)
    }

    static func allVoices(custom: [BabyVoice]) -> [BabyVoice] { BabyVoice.bundled + custom }

    static func voice(id: String, custom: [BabyVoice]) -> BabyVoice {
        allVoices(custom: custom).first { $0.id == id } ?? BabyVoice.bundled[0]
    }

    /// File name to hand to notifications and AlarmKit.
    static func soundFileName(for id: String, custom: [BabyVoice]) -> String {
        let voice = voice(id: id, custom: custom)
        if voice.isCustom, !FileManager.default.fileExists(atPath: url(for: voice).path) {
            return BabyVoice.bundled[0].fileName
        }
        return voice.fileName
    }

    static func url(for voice: BabyVoice) -> URL {
        if voice.isCustom {
            return soundsDirectory.appendingPathComponent(voice.fileName)
        }
        let name = (voice.fileName as NSString).deletingPathExtension
        let ext = (voice.fileName as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.bundleURL.appendingPathComponent(voice.fileName)
    }

    static func playableURL(id: String, custom: [BabyVoice]) -> URL {
        let voice = voice(id: id, custom: custom)
        let url = url(for: voice)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        return self.url(for: BabyVoice.bundled[0])
    }

    static func newRecordingURL() throws -> URL {
        try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        return soundsDirectory.appendingPathComponent("custom_\(UUID().uuidString)")
            .appendingPathExtension("caf")
    }

    static func delete(_ voice: BabyVoice) {
        guard voice.isCustom else { return }
        try? FileManager.default.removeItem(at: url(for: voice))
    }

    /// Converts any audio file iOS can read into a 16-bit PCM CAF in `Library/Sounds`,
    /// trimmed to the notification sound limit, and returns the new voice.
    static func importAudio(from source: URL, name: String) throws -> BabyVoice {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let destination = try newRecordingURL()
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let output = try AVAudioFile(forWriting: destination, settings: settings,
                                     commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        let maxFrames = AVAudioFramePosition(format.sampleRate * BabyVoice.maximumNotificationSeconds)
        let chunk: AVAudioFrameCount = 8192
        var written: AVAudioFramePosition = 0
        while input.framePosition < input.length, written < maxFrames {
            let remaining = AVAudioFrameCount(min(AVAudioFramePosition(chunk), maxFrames - written))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: remaining) else { break }
            try input.read(into: buffer, frameCount: remaining)
            if buffer.frameLength == 0 { break }
            try output.write(from: buffer)
            written += AVAudioFramePosition(buffer.frameLength)
        }
        return BabyVoice(id: "custom-\(UUID().uuidString)", name: name,
                         detail: "Imported recording", origin: .imported,
                         fileName: destination.lastPathComponent)
    }
}

/// Records the user's own baby with the microphone.
@MainActor
final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0
    @Published private(set) var recordedURL: URL?
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start() {
        Task {
            guard await Self.requestPermission() else {
                errorMessage = "Microphone access is off. Enable it in Settings to record your baby."
                return
            }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)
                let url = try VoiceLibrary.newRecordingURL()
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 22_050,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                ]
                let recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder.delegate = self
                recorder.isMeteringEnabled = true
                recorder.record(forDuration: BabyVoice.maximumNotificationSeconds)
                self.recorder = recorder
                recordedURL = nil
                isRecording = true
                elapsed = 0
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.refresh() }
                }
            } catch {
                errorMessage = "Could not start recording: \(error.localizedDescription)"
            }
        }
    }

    func stop() {
        recorder?.stop()
    }

    func discard() {
        if let url = recordedURL { try? FileManager.default.removeItem(at: url) }
        recordedURL = nil
        elapsed = 0
    }

    private func refresh() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime
        let power = recorder.averagePower(forChannel: 0)
        level = max(0, min(1, (power + 50) / 50))
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        Task { @MainActor in
            self.timer?.invalidate()
            self.timer = nil
            self.isRecording = false
            self.level = 0
            self.recordedURL = flag ? url : nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

/// Plays a short preview of a voice in the picker.
@MainActor
final class VoicePreviewPlayer: ObservableObject {
    @Published private(set) var playingID: String?
    private var player: AVAudioPlayer?

    func toggle(_ voice: BabyVoice) {
        if playingID == voice.id {
            stop()
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: VoiceLibrary.url(for: voice))
            player?.volume = 0.6
            player?.play()
            playingID = voice.id
            let duration = min(player?.duration ?? 6, 6)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                if self?.playingID == voice.id { self?.stop() }
            }
        } catch {
            playingID = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }
}
