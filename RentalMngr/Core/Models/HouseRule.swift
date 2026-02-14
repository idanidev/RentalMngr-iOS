import Foundation

enum HouseRuleCategory: String, Codable, Sendable, CaseIterable {
    case limpieza
    case ruido
    case visitas
    case cocina
    case baño = "baño"
    case comunidad
    case otro
}

struct HouseRule: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var category: HouseRuleCategory
    var title: String
    var description: String?
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, category, title, description
        case propertyId = "property_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
