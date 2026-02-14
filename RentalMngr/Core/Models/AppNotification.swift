import Foundation

enum NotificationType: String, Codable, Sendable {
    case contractExpiring = "contract_expiring"
    case contractExpired = "contract_expired"
    case weeklyReport = "weekly_report"
    case invitation = "invitation"
    case expense = "expense"
    case income = "income"
    case roomChange = "room_change"
}

struct AppNotification: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: UUID
    var propertyId: UUID?
    var type: NotificationType
    var title: String
    var message: String
    var metadata: [String: String]?
    var read: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, title, message, metadata, read
        case userId = "user_id"
        case propertyId = "property_id"
        case createdAt = "created_at"
    }
}
