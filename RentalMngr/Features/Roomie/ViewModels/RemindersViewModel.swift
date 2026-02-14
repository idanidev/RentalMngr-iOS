import Foundation

@Observable
final class RemindersViewModel {
    var reminders: [Reminder] = []
    var showCompleted = false
    var isLoading = false
    var errorMessage: String?

    let propertyId: UUID
    private let reminderService: ReminderService

    init(propertyId: UUID, reminderService: ReminderService) {
        self.propertyId = propertyId
        self.reminderService = reminderService
    }

    var filteredReminders: [Reminder] {
        showCompleted ? reminders : reminders.filter { !$0.completed }
    }

    func loadReminders() async {
        isLoading = true
        do {
            reminders = try await reminderService.fetchReminders(propertyId: propertyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleCompleted(_ reminder: Reminder) async {
        do {
            try await reminderService.toggleCompleted(reminderId: reminder.id, completed: !reminder.completed)
            await loadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteReminder(_ reminder: Reminder) async {
        do {
            try await reminderService.deleteReminder(id: reminder.id)
            reminders.removeAll { $0.id == reminder.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
