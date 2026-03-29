import UIKit
import UserNotifications
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "SystemNotification")

/// Manages system-level local notifications (UNUserNotificationCenter)
final class SystemNotificationService: NSObject, SystemNotificationServiceProtocol,
    UNUserNotificationCenterDelegate
{
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

    /// Cancels any pending payment reminders (no longer schedules hourly notifications)
    func updatePaymentReminders(pendingCount: Int) {
        // Cancel any previously scheduled payment reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "hourly_payment_reminder"
        ])
        // Note: Pending payment alerts are now surfaced via the in-app Alerts tab (LocalAlertService)
        // rather than recurring OS notifications, to avoid notification fatigue.
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
