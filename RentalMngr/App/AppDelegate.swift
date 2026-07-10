import UIKit
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "AppDelegate")

/// Minimal UIKit app delegate bridged into the SwiftUI lifecycle via
/// `@UIApplicationDelegateAdaptor`. Its only job is APNs remote-notification
/// registration, forwarded to `PushManager`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        logger.info("Registered for remote notifications")
        Task { @MainActor in
            await PushManager.shared?.handleDeviceToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("Remote notification registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        // Server push received (alert or silent). Hook for future deep-linking.
        logger.info("Received remote notification")
        return .newData
    }
}
