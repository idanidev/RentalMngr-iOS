import Foundation

enum AccessRole: String, Codable, Sendable, CaseIterable {
    case owner
    case editor
    case viewer
}

struct PropertyAccess: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    let userId: UUID
    let role: AccessRole
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, role
        case propertyId = "property_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
