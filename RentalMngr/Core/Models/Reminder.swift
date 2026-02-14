import Foundation

enum ReminderType: String, Codable, Sendable, CaseIterable {
    case pago
    case reunion
    case limpieza
    case evento
    case otro
}

struct Reminder: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var title: String
    var description: String?
    var reminderType: ReminderType
    var dueDate: Date
    var dueTime: String?
    var completed: Bool
    var completedAt: Date?
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, completed
        case propertyId = "property_id"
        case reminderType = "reminder_type"
        case dueDate = "due_date"
        case dueTime = "due_time"
        case completedAt = "completed_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
