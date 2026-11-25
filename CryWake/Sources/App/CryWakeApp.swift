import SwiftUI
import UIKit
import UserNotifications

/// Long-lived objects shared by the whole app.
final class AppServices {
    static let shared = AppServices()
    let store: AlarmStore
    let engine: AlarmEngine

    private init() {
        store = AlarmStore()
        engine = AlarmEngine(store: store)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Must be set before launch finishes so a tap on an alarm notification reaches us.
        UNUserNotificationCenter.current().delegate = AppServices.shared.engine
        AppServices.shared.engine.start()
        return true
    }
}

@main
struct CryWakeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AppServices.shared.store)
                .environmentObject(AppServices.shared.engine)
                .environmentObject(AppServices.shared.engine.player)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { AppServices.shared.engine.sceneBecameActive() }
        }
    }
}
