import Foundation

enum NotificationType: String, Codable, Sendable {
    case contractExpiring = "contract_expiring"
    case contractExpired = "contract_expired"
    case weeklyReport = "weekly_report"
    case invitation = "invitation"
    case expense = "expense"
    case income = "income"
    case roomChange = "room_change"
    case unknown = "unknown"
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        propertyId = try container.decodeIfPresent(UUID.self, forKey: .propertyId)
        let rawType = try container.decode(String.self, forKey: .type)
        type = NotificationType(rawValue: rawType) ?? .unknown
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        metadata = (try? container.decodeIfPresent([String: String].self, forKey: .metadata)) ?? nil
        read = try container.decode(Bool.self, forKey: .read)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
