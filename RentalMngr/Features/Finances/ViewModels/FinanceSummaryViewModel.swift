import Foundation

@Observable
final class FinanceSummaryViewModel {
    var expenses: [Expense] = []
    var income: [Income] = []
    var summary: FinancialSummary?
    var selectedSection: FinanceSection = .summary
    var isLoading = false
    var errorMessage: String?

    /// Date filtering — matches webapp (year/month picker)
    var selectedDate: Date = Date()
    var filterByDate = false

    let propertyId: UUID
    private let financeService: FinanceService

    init(propertyId: UUID, financeService: FinanceService) {
        self.propertyId = propertyId
        self.financeService = financeService
    }

    private var selectedYear: Int? {
        guard filterByDate else { return nil }
        return Calendar.current.component(.year, from: selectedDate)
    }

    private var selectedMonth: Int? {
        guard filterByDate else { return nil }
        return Calendar.current.component(.month, from: selectedDate)
    }

    private var startDate: Date? {
        guard filterByDate, let year = selectedYear, let month = selectedMonth else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components)
    }

    private var endDate: Date? {
        guard let start = startDate else { return nil }
        return Calendar.current.date(byAdding: DateComponents(month: 1, second: -1), to: start)
    }

    func loadData() async {
        isLoading = true
        do {
            async let fetchExpenses = financeService.fetchExpenses(
                propertyId: propertyId, startDate: startDate, endDate: endDate
            )
            async let fetchIncome = financeService.fetchIncome(
                propertyId: propertyId, startDate: startDate, endDate: endDate
            )
            async let fetchSummary = financeService.getFinancialSummary(
                propertyId: propertyId, year: selectedYear, month: selectedMonth
            )
            expenses = try await fetchExpenses
            income = try await fetchIncome
            summary = try await fetchSummary
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteExpense(_ expense: Expense) async {
        do {
            try await financeService.deleteExpense(id: expense.id)
            expenses.removeAll { $0.id == expense.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePaid(_ item: Income) async {
        do {
            if item.paid {
                try await financeService.markAsUnpaid(incomeId: item.id)
            } else {
                try await financeService.markAsPaid(incomeId: item.id)
            }
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Expenses grouped by category with summed amounts
    var expensesByCategory: [(category: String, amount: Decimal)] {
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped.map { (category: $0.key, amount: $0.value.reduce(Decimal.zero) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
}

enum FinanceSection: String, CaseIterable {
    case summary = "Resumen"
    case expenses = "Gastos"
    case income = "Ingresos"
}
