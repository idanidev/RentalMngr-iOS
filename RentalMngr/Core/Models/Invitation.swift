import Foundation

struct Invitation: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var email: String
    var role: AccessRole
    let token: UUID
    let expiresAt: Date
    let createdBy: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, role, token
        case propertyId = "property_id"
        case expiresAt = "expires_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}
