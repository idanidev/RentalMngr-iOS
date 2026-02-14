import Foundation

enum SharedExpenseCategory: String, Codable, Sendable, CaseIterable {
    case servicios
    case compras
    case reparaciones
    case limpieza
    case otro
}

enum SplitType: String, Codable, Sendable, CaseIterable {
    case equal
    case custom
    case byRoom = "by_room"
}

struct SharedExpense: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var title: String
    var description: String?
    var amount: Decimal
    var category: SharedExpenseCategory
    var date: Date
    var splitType: SplitType
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, amount, category, date
        case propertyId = "property_id"
        case splitType = "split_type"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
