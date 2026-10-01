import UIKit
import UserNotifications

/// Notifications push : jeton de l'iPhone, affichage au premier plan, ouverture d'une notification.
/// Les évènements sont relayés à l'`AppModel` par des fermetures posées au lancement.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor static var onToken: ((Data) -> Void)?
    @MainActor static var onOpen: (([AnyHashable: Any]) -> Void)?
    /// Jeton reçu avant que l'app soit prête.
    @MainActor static var pendingToken: Data?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            if let onToken = Self.onToken { onToken(deviceToken) } else { Self.pendingToken = deviceToken }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        Task { @MainActor in Self.onOpen?(info) }
        completionHandler()
    }
}
