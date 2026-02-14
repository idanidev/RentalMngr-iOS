import Foundation

struct Expense: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var roomId: UUID?
    var amount: Decimal
    var category: String
    var description: String?
    var date: Date
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    // Embedded relationships
    var property: ExpenseProperty?
    var room: ExpenseRoom?

    enum CodingKeys: String, CodingKey {
        case id, amount, category, description, date, room, property
        case propertyId = "property_id"
        case roomId = "room_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ExpenseProperty: Codable, Sendable, Hashable {
    let name: String
}

struct ExpenseRoom: Codable, Sendable, Hashable {
    let name: String
}
