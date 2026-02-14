import Foundation

/// Groups income data across all properties for the global finance view
@Observable
final class GlobalFinanceViewModel {
    var properties: [Property] = []
    var incomeByProperty: [UUID: [Income]] = [:]
    var isLoading = false
    var errorMessage: String?
    var selectedDate = Date()

    private let propertyService: PropertyService
    private let financeService: FinanceService

    init(propertyService: PropertyService, financeService: FinanceService) {
        self.propertyService = propertyService
        self.financeService = financeService
    }

    // MARK: - Computed

    var totalExpected: Decimal {
        incomeByProperty.values.flatMap { $0 }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var totalPaid: Decimal {
        incomeByProperty.values.flatMap { $0 }.filter(\.paid).reduce(Decimal.zero) {
            $0 + $1.amount
        }
    }

    var totalPending: Decimal {
        totalExpected - totalPaid
    }

    var paidCount: Int {
        incomeByProperty.values.flatMap { $0 }.filter(\.paid).count
    }

    var unpaidCount: Int {
        incomeByProperty.values.flatMap { $0 }.filter { !$0.paid }.count
    }

    /// All properties, sorted by name
    var propertiesWithIncome: [Property] {
        properties.sorted { $0.name < $1.name }
    }

    func incomeForProperty(_ propertyId: UUID) -> [Income] {
        (incomeByProperty[propertyId] ?? []).sorted { a, b in
            // Unpaid first, then by room name
            if a.paid != b.paid { return !a.paid }
            return (a.room?.name ?? "") < (b.room?.name ?? "")
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch all properties
            properties = try await propertyService.fetchProperties()

            // Calculate month range
            let calendar = Calendar.current
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: selectedDate))!
            let endOfMonth = calendar.date(
                byAdding: DateComponents(month: 1, second: -1), to: startOfMonth)!

            // Fetch income for all properties
            let allIncome = try await financeService.fetchAllIncome(
                propertyIds: properties.map(\.id),
                startDate: startOfMonth,
                endDate: endOfMonth
            )

            // Group by property
            incomeByProperty = Dictionary(grouping: allIncome, by: \.propertyId)

        } catch {
            errorMessage = error.localizedDescription
            print("[GlobalFinanceVM] Error: \(error)")
        }

        isLoading = false
    }

    func changeMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedDate) {
            selectedDate = newDate
            Task { await loadData() }
        }
    }

    // MARK: - Actions

    func markAsPaid(_ income: Income) async {
        do {
            try await financeService.markAsPaid(incomeId: income.id)
            // Update local state
            if var list = incomeByProperty[income.propertyId] {
                if let idx = list.firstIndex(where: { $0.id == income.id }) {
                    list[idx].paid = true
                    list[idx].paymentDate = Date()
                    incomeByProperty[income.propertyId] = list
                }
            }
        } catch {
            print("[GlobalFinanceVM] Error marking paid: \(error)")
        }
    }

    func markAsUnpaid(_ income: Income) async {
        do {
            try await financeService.markAsUnpaid(incomeId: income.id)
            if var list = incomeByProperty[income.propertyId] {
                if let idx = list.firstIndex(where: { $0.id == income.id }) {
                    list[idx].paid = false
                    list[idx].paymentDate = nil
                    incomeByProperty[income.propertyId] = list
                }
            }
        } catch {
            print("[GlobalFinanceVM] Error marking unpaid: \(error)")
        }
    }

    // MARK: - Formatting

    var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: selectedDate).capitalized
    }
}
