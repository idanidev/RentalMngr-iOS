import Foundation
import Supabase

final class NotificationAppService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Notifications CRUD

    func fetchNotifications(userId: UUID, limit: Int = 50, offset: Int = 0, unreadOnly: Bool = false) async throws -> [AppNotification] {
        var query = client
            .from("notifications")
            .select()
            .eq("user_id", value: userId)

        if unreadOnly {
            query = query.eq("read", value: false)
        }

        return try await query
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }

    func fetchNotificationsByType(userId: UUID, type: NotificationType) async throws -> [AppNotification] {
        try await client
            .from("notifications")
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
            .from("notifications")
            .update(ReadUpdate())
            .eq("id", value: id)
            .execute()
    }

    func markAllAsRead(userId: UUID) async throws {
        struct ReadUpdate: Encodable { let read = true }
        try await client
            .from("notifications")
            .update(ReadUpdate())
            .eq("user_id", value: userId)
            .eq("read", value: false)
            .execute()
    }

    func getUnreadCount(userId: UUID) async throws -> Int {
        let response: [AppNotification] = try await client
            .from("notifications")
            .select()
            .eq("user_id", value: userId)
            .eq("read", value: false)
            .execute()
            .value
        return response.count
    }

    func deleteNotification(id: UUID) async throws {
        try await client
            .from("notifications")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Test Notification (matches webapp createTestNotification)

    func createTestNotification(userId: UUID, propertyId: UUID?) async throws {
        struct NewNotification: Encodable {
            let user_id: UUID
            let property_id: UUID?
            let type: String
            let title: String
            let message: String
            let metadata: [String: String]
            let read: Bool
        }
        try await client
            .from("notifications")
            .insert(NewNotification(
                user_id: userId,
                property_id: propertyId,
                type: NotificationType.weeklyReport.rawValue,
                title: "Notificación de prueba",
                message: "Esta es una notificación de prueba para verificar que el sistema funciona correctamente.",
                metadata: ["test": "true", "created_at": ISO8601DateFormatter().string(from: Date())],
                read: false
            ))
            .execute()
    }

    // MARK: - Settings

    func fetchSettings(userId: UUID) async throws -> NotificationSettings? {
        let results: [NotificationSettings] = try await client
            .from("notification_settings")
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
        return try await client
            .from("notification_settings")
            .insert(NewSettings(
                user_id: userId,
                contract_alert_days: [7, 15, 30],
                enable_contract_alerts: true,
                enable_weekly_report: true,
                enable_invitation_alerts: true,
                enable_expense_alerts: true,
                enable_income_alerts: false,
                enable_room_alerts: false
            ))
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
            .from("notification_settings")
            .update(UpdateSettings(
                contract_alert_days: settings.contractAlertDays,
                enable_contract_alerts: settings.enableContractAlerts,
                enable_weekly_report: settings.enableWeeklyReport,
                enable_invitation_alerts: settings.enableInvitationAlerts,
                enable_expense_alerts: settings.enableExpenseAlerts,
                enable_income_alerts: settings.enableIncomeAlerts,
                enable_room_alerts: settings.enableRoomAlerts
            ))
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
}
