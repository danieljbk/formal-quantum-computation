import AVFoundation
import CoreLocation
import CoreMotion
import Foundation
import SwiftUI
import UIKit
import UserNotifications
import Vision

// MARK: - App settings

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var theme: AppTheme = .system
    var zodiac: Zodiac = .aries
    var showBriefingAfterAlarm = true
    var briefingWeather = true
    /// Missions pre-filled for new alarms.
    var defaultMissions: [MissionSettings] = [MissionSettings(kind: .math)]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        zodiac = try c.decodeIfPresent(Zodiac.self, forKey: .zodiac) ?? .aries
        showBriefingAfterAlarm = try c.decodeIfPresent(Bool.self, forKey: .showBriefingAfterAlarm) ?? true
        briefingWeather = try c.decodeIfPresent(Bool.self, forKey: .briefingWeather) ?? true
        defaultMissions = try c.decodeIfPresent([MissionSettings].self, forKey: .defaultMissions) ?? [MissionSettings(kind: .math)]
    }
}

final class AppSettingsStore: ObservableObject {
    static let shared = AppSettingsStore()
    private let key = "babyalarm.preferences.v1"
    private let defaults: UserDefaults

    @Published var prefs: AppPreferences {
        didSet {
            if let data = try? JSONEncoder().encode(prefs) { defaults.set(data, forKey: key) }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let p = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            prefs = p
        } else {
            prefs = AppPreferences()
        }
    }
}

// MARK: - Motion: steps and squats

final class MotionMonitor: ObservableObject {
    private let pedometer = CMPedometer()
    private let manager = CMMotionManager()
    private var shake = ShakeDetector()
    private var squat = SquatDetector()

    static var stepsAvailable: Bool { CMPedometer.isStepCountingAvailable() }
    static var motionAvailable: Bool { CMMotionManager().isDeviceMotionAvailable }

    func startSteps(onUpdate: @escaping (Int) -> Void) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: Date()) { data, _ in
            guard let steps = data?.numberOfSteps.intValue else { return }
            DispatchQueue.main.async { onUpdate(steps) }
        }
    }

    func startShake(onShake: @escaping () -> Void) {
        startDeviceMotion { [weak self] motion in
            guard let self else { return }
            let a = motion.userAcceleration
            if self.shake.ingest(x: a.x, y: a.y, z: a.z, at: motion.timestamp) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onShake()
            }
        }
    }

    func startSquats(onSquat: @escaping () -> Void) {
        startDeviceMotion { [weak self] motion in
            guard let self else { return }
            let a = motion.userAcceleration
            let g = motion.gravity
            let norm = max(0.0001, (g.x * g.x + g.y * g.y + g.z * g.z).squareRoot())
            // Gravity points down, so the upward component is minus the projection onto it.
            let up = -(a.x * g.x + a.y * g.y + a.z * g.z) / norm
            if self.squat.ingest(vertical: up, at: motion.timestamp) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onSquat()
            }
        }
    }

    private func startDeviceMotion(_ handler: @escaping (CMDeviceMotion) -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(to: .main) { data, _ in
            if let data { handler(data) }
        }
    }

    func stop() {
        pedometer.stopUpdates()
        manager.stopDeviceMotionUpdates()
    }
}

// MARK: - Weather for the morning briefing

final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherService()

    @Published private(set) var report: WeatherReport?
    @Published private(set) var status: String = "Weather not loaded yet"
    private let location = CLLocationManager()
    private var lastFetch: Date?

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorization: CLAuthorizationStatus { location.authorizationStatus }

    func refresh(force: Bool = false) {
        if !force, let last = lastFetch, Date().timeIntervalSince(last) < 30 * 60, report != nil { return }
        switch location.authorizationStatus {
        case .notDetermined:
            status = "Allow location for local weather"
            location.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = "Location is off, so no weather"
        default:
            status = "Finding your weather…"
            location.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, let url = WeatherReport.url(latitude: loc.coordinate.latitude,
                                                                      longitude: loc.coordinate.longitude) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            let report = data.flatMap(WeatherReport.decode)
            DispatchQueue.main.async {
                if let report {
                    self?.report = report
                    self?.lastFetch = Date()
                    self?.status = ""
                } else {
                    self?.status = error == nil ? "Weather unavailable" : "Weather needs an internet connection"
                }
            }
        }.resume()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        status = "Couldn't find your location"
    }
}

// MARK: - Photo mission

enum PhotoStore {
    static var directory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MissionPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ image: UIImage) -> String? {
        let name = "\(UUID().uuidString).jpg"
        guard let data = image.resized(maxSide: 1024).jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: directory.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }

    /// Vision feature-print distance between two photos (smaller = more alike).
    static func distance(_ a: UIImage, _ b: UIImage) -> Double? {
        func featurePrint(_ image: UIImage) -> VNFeaturePrintObservation? {
            guard let cg = image.resized(maxSide: 512).cgImage else { return nil }
            let request = VNGenerateImageFeaturePrintRequest()
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        }
        guard let pa = featurePrint(a), let pb = featurePrint(b) else { return nil }
        var d: Float = 0
        guard (try? pa.computeDistance(&d, to: pb)) != nil else { return nil }
        return Double(d)
    }
}

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}

// MARK: - Permissions checklist

struct PermissionRow: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let state: State

    enum State { case granted, denied, notAsked, unavailable }
}

enum PermissionCenter {
    static func rows(notifications: UNAuthorizationStatus) -> [PermissionRow] {
        var rows: [PermissionRow] = []
        let notif: PermissionRow.State
        switch notifications {
        case .authorized, .provisional, .ephemeral: notif = .granted
        case .denied: notif = .denied
        default: notif = .notAsked
        }
        rows.append(PermissionRow(id: "notifications", title: "Notifications", detail: "Rings when the app is closed",
                                  symbol: "bell.badge.fill", state: notif))

        let mic: PermissionRow.State
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: mic = .granted
            case .denied: mic = .denied
            default: mic = .notAsked
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted: mic = .granted
            case .denied: mic = .denied
            default: mic = .notAsked
            }
        }
        rows.append(PermissionRow(id: "microphone", title: "Microphone", detail: "Snore & sleep-talk recording",
                                  symbol: "mic.fill", state: mic))

        let cam: PermissionRow.State
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: cam = .granted
            case .denied, .restricted: cam = .denied
            default: cam = .notAsked
            }
        } else {
            cam = .unavailable
        }
        rows.append(PermissionRow(id: "camera", title: "Camera", detail: "Photo and barcode missions",
                                  symbol: "camera.fill", state: cam))

        let motion: PermissionRow.State
        if !CMPedometer.isStepCountingAvailable() {
            motion = .unavailable
        } else {
            switch CMPedometer.authorizationStatus() {
            case .authorized: motion = .granted
            case .denied, .restricted: motion = .denied
            default: motion = .notAsked
            }
        }
        rows.append(PermissionRow(id: "motion", title: "Motion & Fitness", detail: "Steps mission",
                                  symbol: "figure.walk", state: motion))

        let loc: PermissionRow.State
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: loc = .granted
        case .denied, .restricted: loc = .denied
        default: loc = .notAsked
        }
        rows.append(PermissionRow(id: "location", title: "Location", detail: "Weather in the morning briefing",
                                  symbol: "location.fill", state: loc))
        return rows
    }
}
