import Foundation

@MainActor @Observable
final class SharedExpensesViewModel {
    var sharedExpenses: [SharedExpense] = []
    var isLoading = false
    var errorMessage: String?

    let propertyId: UUID
    private let sharedExpenseService: SharedExpenseServiceProtocol

    init(propertyId: UUID, sharedExpenseService: SharedExpenseServiceProtocol) {
        self.propertyId = propertyId
        self.sharedExpenseService = sharedExpenseService
    }

    func loadExpenses() async {
        isLoading = true
        do {
            sharedExpenses = try await sharedExpenseService.fetchSharedExpenses(propertyId: propertyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteExpense(_ expense: SharedExpense) async {
        do {
            try await sharedExpenseService.deleteSharedExpense(id: expense.id)
            sharedExpenses.removeAll { $0.id == expense.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
