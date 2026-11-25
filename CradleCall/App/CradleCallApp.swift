import SwiftUI
import UIKit
import UserNotifications

@main
struct CradleCallApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appDelegate.model)
                .task { await appDelegate.model.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            appDelegate.model.scenePhaseChanged(phase)
        }
    }
}

/// Owns the model so notification callbacks can reach it even before the UI exists.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let model = AppModel()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        model.appWillTerminate()
    }

    /// In the foreground the app rings itself instead of showing the banner.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        let content = notification.request.content
        let category = content.categoryIdentifier
        let info = AlarmNotificationInfo(userInfo: content.userInfo)
        return await MainActor.run { () -> UNNotificationPresentationOptions in
            switch category {
            case NotificationService.alarmCategory:
                if let info { model.ringFromExternal(alarmID: info.alarmID, scheduledAt: info.scheduledAt, tag: info.tag) }
                return []
            case NotificationService.wakeCheckCategory:
                if model.overlay == nil { model.overlay = .wakeUpCheck }
                return []
            default:
                return [.banner, .sound, .list]
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        let category = content.categoryIdentifier
        let action = response.actionIdentifier
        let info = AlarmNotificationInfo(userInfo: content.userInfo)
        await MainActor.run {
            switch category {
            case NotificationService.alarmCategory:
                if let info { model.ringFromExternal(alarmID: info.alarmID, scheduledAt: info.scheduledAt, tag: info.tag) }
            case NotificationService.wakeCheckCategory:
                if action == NotificationService.confirmAwakeAction
                    || action == UNNotificationDefaultActionIdentifier {
                    model.confirmAwake()
                }
            default:
                break
            }
        }
    }
}

/// The parts of an alarm notification's payload the app needs.
struct AlarmNotificationInfo: Sendable {
    var alarmID: UUID
    var scheduledAt: Date?
    var tag: String?

    init?(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo["alarmID"] as? String, let id = UUID(uuidString: raw) else { return nil }
        alarmID = id
        scheduledAt = (userInfo["scheduledAt"] as? Double).map(Date.init(timeIntervalSince1970:))
        tag = userInfo["tag"] as? String
    }
}
