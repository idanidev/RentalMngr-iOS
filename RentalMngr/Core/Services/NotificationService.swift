import Foundation
import Supabase
import UserNotifications
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "NotificationService")

final class NotificationAppService: NotificationServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Notifications CRUD

    func fetchNotifications(
        userId: UUID, limit: Int = 50, offset: Int = 0, unreadOnly: Bool = false
    ) async throws -> [AppNotification] {
        var query =
            client
            .from(SupabaseTable.notifications)
            .select()
            .eq("user_id", value: userId)

        if unreadOnly {
            query = query.eq("read", value: false)
        }

        return
            try await query
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }

    func fetchNotificationsByType(userId: UUID, type: NotificationType) async throws
        -> [AppNotification]
    {
        try await client
            .from(SupabaseTable.notifications)
            .select()
            .eq("user_id", value: userId)
            .eq("type", value: type.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func markAsRead(id: UUID) async throws {
        struct ReadUpdate: Encodable { let read = true }
        try await client
            .from(SupabaseTable.notifications)
            .update(ReadUpdate())
            .eq("id", value: id)
            .execute()
    }

    func markAllAsRead(userId: UUID) async throws {
        struct ReadUpdate: Encodable { let read = true }
        try await client
            .from(SupabaseTable.notifications)
            .update(ReadUpdate())
            .eq("user_id", value: userId)
            .eq("read", value: false)
            .execute()
    }

    func getUnreadCount(userId: UUID) async throws -> Int {
        // Use HEAD + count to avoid fetching rows — accurate even beyond the 1000-row default limit
        let response =
            try await client
            .from(SupabaseTable.notifications)
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .eq("read", value: false)
            .execute()
        return response.count ?? 0
    }

    func deleteNotification(id: UUID) async throws {
        try await client
            .from(SupabaseTable.notifications)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Settings

    func fetchSettings(userId: UUID) async throws -> NotificationSettings? {
        let results: [NotificationSettings] =
            try await client
            .from(SupabaseTable.notificationSettings)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return results.first
    }

    /// Creates default settings if none exist (matches webapp createDefaultSettings)
    func createDefaultSettings(userId: UUID) async throws -> NotificationSettings {
        struct NewSettings: Encodable {
            let user_id: UUID
            let contract_alert_days: [Int]
            let enable_contract_alerts: Bool
            let enable_weekly_report: Bool
            let enable_invitation_alerts: Bool
            let enable_expense_alerts: Bool
            let enable_income_alerts: Bool
            let enable_room_alerts: Bool
        }
        return
            try await client
            .from(SupabaseTable.notificationSettings)
            .insert(
                NewSettings(
                    user_id: userId,
                    contract_alert_days: [7, 15, 30],
                    enable_contract_alerts: true,
                    enable_weekly_report: true,
                    enable_invitation_alerts: true,
                    enable_expense_alerts: true,
                    enable_income_alerts: false,
                    enable_room_alerts: false
                )
            )
            .select()
            .single()
            .execute()
            .value
    }

    func updateSettings(_ settings: NotificationSettings) async throws {
        struct UpdateSettings: Encodable {
            let contract_alert_days: [Int]
            let enable_contract_alerts: Bool
            let enable_weekly_report: Bool
            let enable_invitation_alerts: Bool
            let enable_expense_alerts: Bool
            let enable_income_alerts: Bool
            let enable_room_alerts: Bool
        }
        try await client
            .from(SupabaseTable.notificationSettings)
            .update(
                UpdateSettings(
                    contract_alert_days: settings.contractAlertDays,
                    enable_contract_alerts: settings.enableContractAlerts,
                    enable_weekly_report: settings.enableWeeklyReport,
                    enable_invitation_alerts: settings.enableInvitationAlerts,
                    enable_expense_alerts: settings.enableExpenseAlerts,
                    enable_income_alerts: settings.enableIncomeAlerts,
                    enable_room_alerts: settings.enableRoomAlerts
                )
            )
            .eq("id", value: settings.id)
            .execute()
    }

    /// Fetch settings or create defaults if none exist
    func fetchOrCreateSettings(userId: UUID) async throws -> NotificationSettings {
        if let existing = try await fetchSettings(userId: userId) {
            return existing
        }
        return try await createDefaultSettings(userId: userId)
    }

    // MARK: - Local Notifications

    func requestLocalPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleContractExpiry(
        tenantName: String, expiryDate: Date, tenantId: UUID, alertDays: [Int]
    ) async {
        let center = UNUserNotificationCenter.current()
        await cancelContractExpiry(tenantId: tenantId)

        for days in alertDays {
            // Check if date is valid (expiry - days > now)
            guard
                let triggerDate = Calendar.current.date(
                    byAdding: .day, value: -days, to: expiryDate),
                triggerDate > Date()
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "Contract Renewal", locale: LanguageService.currentLocale, comment: "Notification title for contract expiry")
            content.body = String(localized: "\(tenantName)'s contract expires in \(days) days.",
                locale: LanguageService.currentLocale, comment: "Notification body for contract expiry")
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let identifier = "contract_expiry_\(tenantId)_\(days)"
            let request = UNNotificationRequest(
                identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                logger.error("Failed to schedule contract expiry notification: \(error)")
            }
        }
    }

    func scheduleRentReminders() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["rent_reminder"])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Rent Collection", locale: LanguageService.currentLocale, comment: "Notification title for monthly rent reminder")
        content.body = String(localized: "Remember to check this month's rent payments.",
            locale: LanguageService.currentLocale, comment: "Notification body for monthly rent reminder")
        content.sound = .default

        // Schedule for day 1 of every month at 9:00 AM
        var components = DateComponents()
        components.day = 1
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "rent_reminder", content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to schedule rent reminder notification: \(error)")
        }
    }

    func scheduleWeeklyReport(weekday: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly_report"])

        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "Weekly summary",
            locale: LanguageService.currentLocale,
            comment: "Toggle title for weekly report notification")
        content.body = String(
            localized: "Occupancy, income and outstanding payments — every Monday at 9:00 AM",
            locale: LanguageService.currentLocale,
            comment: "Subtitle describing weekly report schedule and content")
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly_report", content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to schedule weekly report notification: \(error)")
        }
    }

    func cancelWeeklyReport() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["weekly_report"])
    }

    func cancelContractExpiry(tenantId: UUID) async {
        let center = UNUserNotificationCenter.current()
        // Query all pending requests and cancel any matching this tenant — regardless of alert day
        let pending = await center.pendingNotificationRequests()
        let prefix = "contract_expiry_\(tenantId)_"
        let ids = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
