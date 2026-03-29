import Foundation

@MainActor @Observable
final class RemindersViewModel {
    var reminders: [Reminder] = []
    var showCompleted = false
    var isLoading = false
    private(set) var isLoaded = false
    var errorMessage: String?

    let propertyId: UUID
    private let reminderService: ReminderServiceProtocol

    init(propertyId: UUID, reminderService: ReminderServiceProtocol) {
        self.propertyId = propertyId
        self.reminderService = reminderService
    }

    var filteredReminders: [Reminder] {
        showCompleted ? reminders : reminders.filter { !$0.completed }
    }

    func loadReminders() async {
        guard !isLoaded else { return }
        isLoading = true
        errorMessage = nil
        do {
            reminders = try await reminderService.fetchReminders(propertyId: propertyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoaded = true
        isLoading = false
    }

    func refresh() async {
        isLoaded = false
        await loadReminders()
    }

    func toggleCompleted(_ reminder: Reminder) async {
        errorMessage = nil
        do {
            try await reminderService.toggleCompleted(
                reminderId: reminder.id, completed: !reminder.completed)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteReminder(_ reminder: Reminder) async {
        errorMessage = nil
        do {
            try await reminderService.deleteReminder(id: reminder.id)
            reminders.removeAll { $0.id == reminder.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
