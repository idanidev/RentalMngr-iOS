import UIKit
import UserNotifications

/// Manages system-level local notifications (UNUserNotificationCenter)
final class SystemNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SystemNotificationService()

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Request permission for alerts, sounds, and badges
    func requestPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Updates the hourly payment reminder state based on pending count
    func updatePaymentReminders(pendingCount: Int) {
        Task {
            // Remove existing reminders first to reset or cancel
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
                "hourly_payment_reminder"
            ])

            guard pendingCount > 0 else {
                print("[SystemNotificationService] No pending payments. Reminders cancelled.")
                return
            }

            // Check permissions before scheduling
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                print("[SystemNotificationService] Notifications not authorized.")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Pagos pendientes"
            content.body =
                "Tienes \(pendingCount) pago\(pendingCount > 1 ? "s" : "") de alquiler pendientes."
            content.sound = .default

            // Trigger every hour (3600 seconds)
            // repeats: true requires time interval >= 60
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true)

            let request = UNNotificationRequest(
                identifier: "hourly_payment_reminder",
                content: content,
                trigger: trigger
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
                print(
                    "[SystemNotificationService] Scheduled hourly reminder for \(pendingCount) pending payments."
                )
            } catch {
                print("[SystemNotificationService] Error scheduling notification: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
