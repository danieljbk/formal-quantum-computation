import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // The delegate must be in place before launch finishes so a tap on an
        // alarm notification that launched the app is not lost.
        if !AppEnvironment.isRunningTests {
            NotificationService.shared.install()
        }
        return true
    }
}

@main
struct BabyAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var engine = AlarmEngine.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .onAppear { engine.start() }
        }
        .onChange(of: scenePhase) { phase in
            engine.scenePhaseChanged(phase)
        }
    }
}
