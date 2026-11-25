import Foundation
import SwiftUI
#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import AppIntents
#endif

/// On iOS 26+, mirrors upcoming rings into AlarmKit so they sound like the system
/// Clock alarm (through Silent mode and Focus, full-screen on the Lock Screen) even
/// when the app is suspended or force-quit. "Calm the baby" opens the app, where the
/// in-app ring and missions take over. On older iOS this does nothing and the app
/// relies on notifications plus the background keep-alive.
final class SystemAlarmService: ObservableObject {
    static let shared = SystemAlarmService()

    enum Status: Equatable { case unsupported, notDetermined, authorized, denied }

    @Published private(set) var status: Status = .unsupported

    private let idsKey = "babyalarm.systemAlarmIDs.v1"
    private var syncTask: Task<Void, Never>?

    init() {
        refreshStatus()
    }

    var isSupported: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }

    func refreshStatus() {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            switch AlarmManager.shared.authorizationState {
            case .authorized: status = .authorized
            case .denied: status = .denied
            default: status = .notDetermined
            }
            return
        }
        #endif
        status = .unsupported
    }

    func requestAuthorization() {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task { @MainActor in
                _ = try? await AlarmManager.shared.requestAuthorization()
                self.refreshStatus()
            }
        }
        #endif
    }

    /// Replace every system alarm this app scheduled with `items`.
    func sync(_ items: [SystemAlarmItem]) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let previous = syncTask
            syncTask = Task { @MainActor in
                await previous?.value
                await self.apply(items)
            }
        }
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    @MainActor
    private func apply(_ items: [SystemAlarmItem]) async {
        refreshStatus()
        let defaults = UserDefaults.standard
        let old = (defaults.stringArray(forKey: idsKey) ?? []).compactMap(UUID.init(uuidString:))
        for id in old {
            try? AlarmManager.shared.cancel(id: id)
        }
        guard status == .authorized else {
            defaults.set([String](), forKey: idsKey)
            return
        }
        var scheduled: [String] = []
        for item in items {
            let id = UUID()
            let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
            let calm = AlarmButton(text: "Calm the baby", textColor: .white, systemImageName: "hand.raised.fill")
            let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: item.title),
                                                stopButton: stop,
                                                secondaryButton: calm,
                                                secondaryButtonBehavior: .custom)
            let attributes = AlarmAttributes<BabyAlarmMetadata>(presentation: AlarmPresentation(alert: alert),
                                                                tintColor: Theme.pink)
            let configuration = AlarmManager.AlarmConfiguration<BabyAlarmMetadata>(
                countdownDuration: nil,
                schedule: .fixed(item.date),
                attributes: attributes,
                stopIntent: nil,
                secondaryIntent: CalmBabyIntent(identifier: item.identifier),
                sound: .named(item.soundFile))
            do {
                _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
                scheduled.append(id.uuidString)
            } catch {
                continue
            }
        }
        defaults.set(scheduled, forKey: idsKey)
    }
    #endif
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct BabyAlarmMetadata: AlarmMetadata {}

/// "Calm the baby" on the system alarm: opens the app on this ring's mission.
@available(iOS 26.0, *)
struct CalmBabyIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Calm the baby"
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Ring")
    var identifier: String

    init() {}

    init(identifier: String) {
        self.identifier = identifier
    }

    func perform() async throws -> some IntentResult {
        let id = identifier
        await MainActor.run {
            AlarmEngine.shared.openedFromNotification(id)
        }
        return .result()
    }
}
#endif
