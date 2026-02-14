import Foundation

struct NotificationSettings: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: UUID
    var contractAlertDays: [Int]
    var enableContractAlerts: Bool
    var enableWeeklyReport: Bool
    var enableInvitationAlerts: Bool
    var enableExpenseAlerts: Bool
    var enableIncomeAlerts: Bool
    var enableRoomAlerts: Bool
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case contractAlertDays = "contract_alert_days"
        case enableContractAlerts = "enable_contract_alerts"
        case enableWeeklyReport = "enable_weekly_report"
        case enableInvitationAlerts = "enable_invitation_alerts"
        case enableExpenseAlerts = "enable_expense_alerts"
        case enableIncomeAlerts = "enable_income_alerts"
        case enableRoomAlerts = "enable_room_alerts"
        case updatedAt = "updated_at"
    }
}
