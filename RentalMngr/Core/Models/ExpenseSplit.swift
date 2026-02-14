import Foundation

struct ExpenseSplit: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let expenseId: UUID
    var tenantId: UUID?
    var userId: UUID?
    var amount: Decimal
    var paid: Bool
    var paidAt: Date?
    var notes: String?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, amount, paid, notes
        case expenseId = "expense_id"
        case tenantId = "tenant_id"
        case userId = "user_id"
        case paidAt = "paid_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
