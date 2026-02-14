import Foundation
import Supabase

final class ReminderService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func fetchReminders(propertyId: UUID) async throws -> [Reminder] {
        try await client
            .from("reminders")
            .select()
            .eq("property_id", value: propertyId)
            .order("due_date")
            .execute()
            .value
    }

    func fetchPendingReminders(propertyId: UUID) async throws -> [Reminder] {
        try await client
            .from("reminders")
            .select()
            .eq("property_id", value: propertyId)
            .eq("completed", value: false)
            .order("due_date")
            .execute()
            .value
    }

    func createReminder(propertyId: UUID, title: String, description: String?,
                        reminderType: ReminderType, dueDate: Date, dueTime: String?,
                        createdBy: UUID) async throws -> Reminder {
        struct NewReminder: Encodable {
            let property_id: UUID
            let title: String
            let description: String?
            let reminder_type: String
            let due_date: Date
            let due_time: String?
            let created_by: UUID
        }
        return try await client
            .from("reminders")
            .insert(NewReminder(property_id: propertyId, title: title, description: description,
                                reminder_type: reminderType.rawValue, due_date: dueDate,
                                due_time: dueTime, created_by: createdBy))
            .select()
            .single()
            .execute()
            .value
    }

    func toggleCompleted(reminderId: UUID, completed: Bool) async throws {
        struct CompletedUpdate: Encodable {
            let completed: Bool
            let completed_at: Date?
        }
        try await client
            .from("reminders")
            .update(CompletedUpdate(completed: completed, completed_at: completed ? Date() : nil))
            .eq("id", value: reminderId)
            .execute()
    }

    func deleteReminder(id: UUID) async throws {
        try await client
            .from("reminders")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
