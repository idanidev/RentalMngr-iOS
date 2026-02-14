import Foundation

@Observable
final class ExpenseViewModel {
    var amount = ""
    var category = "Mantenimiento"
    var description = ""
    var date = Date()
    var isLoading = false
    var errorMessage: String?

    let propertyId: UUID
    let isEditing: Bool
    private var expenseId: UUID?
    private let financeService: FinanceService
    private let userId: UUID

    static let categories = [
        "Mantenimiento", "Suministros", "Seguros", "Impuestos",
        "Reparaciones", "Limpieza", "Comunidad", "Otro",
    ]

    init(propertyId: UUID, financeService: FinanceService, userId: UUID, expense: Expense? = nil) {
        self.propertyId = propertyId
        self.financeService = financeService
        self.userId = userId
        if let expense {
            self.isEditing = true
            self.expenseId = expense.id
            self.amount = "\(expense.amount)"
            self.category = expense.category
            self.description = expense.description ?? ""
            self.date = expense.date
        } else {
            self.isEditing = false
        }
    }

    var isFormValid: Bool {
        Decimal(string: amount) != nil && !category.isEmpty
    }

    func save() async -> Expense? {
        guard let decimalAmount = Decimal(string: amount) else { return nil }
        isLoading = true
        errorMessage = nil
        do {
            if isEditing, let expenseId {
                let expense = Expense(
                    id: expenseId, propertyId: propertyId, roomId: nil,
                    amount: decimalAmount, category: category,
                    description: description.isEmpty ? nil : description,
                    date: date, createdBy: userId, createdAt: nil, updatedAt: nil
                )
                let result = try await financeService.updateExpense(expense)
                isLoading = false
                return result
            } else {
                let result = try await financeService.createExpense(
                    propertyId: propertyId, amount: decimalAmount, category: category,
                    description: description.isEmpty ? nil : description,
                    date: date, roomId: nil, createdBy: userId
                )
                isLoading = false
                return result
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
