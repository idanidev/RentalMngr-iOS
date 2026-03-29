import Foundation
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "FinanceSummaryVM")

@MainActor @Observable
final class FinanceSummaryViewModel {
    var expenses: [Expense] = []
    var income: [Income] = []
    var utilityCharges: [UtilityCharge] = []
    var propertyUtilities: [PropertyUtility] = []
    var summary: FinancialSummary?
    var selectedSection: FinanceSection = .summary
    var isLoading = false
    private(set) var isLoaded = false
    var errorMessage: String?
    private(set) var expensesByCategory: [(category: String, amount: Decimal)] = []
    private(set) var utilityChargesByRoom: [(roomName: String, tenantName: String?, charges: [UtilityCharge])] = []

    // Pagination
    var isLoadingMore = false
    var hasMoreExpenses = true
    var hasMoreIncome = true
    var hasMoreUtilities = true
    private var expenseOffset = 0
    private var incomeOffset = 0
    private var utilityOffset = 0
    private let limit = 20
    private var isRefreshing = false

    /// Date filtering — matches webapp (year/month picker)
    @ObservationIgnored
    private var _selectedDate: Date =
        UserDefaults.standard.object(forKey: "finance.selectedDate") as? Date ?? Date()
    var selectedDate: Date {
        get {
            access(keyPath: \.selectedDate)
            return _selectedDate
        }
        set {
            withMutation(keyPath: \.selectedDate) {
                _selectedDate = newValue
                UserDefaults.standard.set(newValue, forKey: "finance.selectedDate")
            }
        }
    }

    @ObservationIgnored
    private var _filterByDate: Bool = UserDefaults.standard.bool(forKey: "finance.filterByDate")
    var filterByDate: Bool {
        get {
            access(keyPath: \.filterByDate)
            return _filterByDate
        }
        set {
            withMutation(keyPath: \.filterByDate) {
                _filterByDate = newValue
                UserDefaults.standard.set(newValue, forKey: "finance.filterByDate")
            }
        }
    }

    let propertyId: UUID
    private let financeService: FinanceServiceProtocol
    private let utilityService: UtilityServiceProtocol
    private let realtimeService: RealtimeServiceProtocol

    @ObservationIgnored
    nonisolated(unsafe) private var realtimeTask: Task<Void, Never>?
    @ObservationIgnored
    nonisolated(unsafe) private var refreshDebounceTask: Task<Void, Never>?

    init(
        propertyId: UUID, financeService: FinanceServiceProtocol,
        utilityService: UtilityServiceProtocol,
        realtimeService: RealtimeServiceProtocol
    ) {
        self.propertyId = propertyId
        self.financeService = financeService
        self.utilityService = utilityService
        self.realtimeService = realtimeService
    }

    nonisolated deinit {
        realtimeTask?.cancel()
        refreshDebounceTask?.cancel()
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

    // MARK: - Public

    func loadData() async {
        guard !isLoaded else { return }
        isLoading = true
        errorMessage = nil
        resetPagination()

        if realtimeTask == nil {
            realtimeTask = Task { [weak self] in
                guard let self else { return }
                await self.listenForChanges()
            }
        }

        do {
            try await fetchData()
            isLoaded = true
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isLoading = false
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        isLoaded = false
        await loadData()
    }

    func loadMore() async {
        guard !isLoadingMore && !isRefreshing else { return }
        isLoadingMore = true

        do {
            switch selectedSection {
            case .expenses:
                if hasMoreExpenses {
                    let newExpenses = try await financeService.fetchExpenses(
                        propertyId: propertyId, startDate: startDate, endDate: endDate,
                        limit: limit, offset: expenseOffset
                    )
                    expenses.append(contentsOf: newExpenses)
                    expenseOffset += newExpenses.count
                    hasMoreExpenses = newExpenses.count == limit
                }
            case .income:
                if hasMoreIncome {
                    let newIncome = try await financeService.fetchIncome(
                        propertyId: propertyId, startDate: startDate, endDate: endDate,
                        limit: limit, offset: incomeOffset
                    )
                    income.append(contentsOf: newIncome)
                    incomeOffset += newIncome.count
                    hasMoreIncome = newIncome.count == limit
                }
            case .utilities:
                if hasMoreUtilities {
                    let newUtilities = try await utilityService.fetchUtilityCharges(
                        propertyId: propertyId, startDate: startDate, endDate: endDate,
                        limit: limit, offset: utilityOffset
                    )
                    utilityCharges.append(contentsOf: newUtilities)
                    utilityOffset += newUtilities.count
                    hasMoreUtilities = newUtilities.count == limit
                }
            case .summary:
                break
            }
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isLoadingMore = false
            return
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    func deleteExpense(_ expense: Expense) async {
        do {
            try await financeService.deleteExpense(id: expense.id)
            expenses.removeAll { $0.id == expense.id }
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
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
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleUtilityPaid(_ charge: UtilityCharge) async {
        do {
            if charge.paid {
                try await utilityService.markUtilityUnpaid(chargeId: charge.id)
            } else {
                try await utilityService.markUtilityPaid(chargeId: charge.id)
            }
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func resetPagination() {
        expenseOffset = 0
        incomeOffset = 0
        utilityOffset = 0
        hasMoreExpenses = true
        hasMoreIncome = true
        hasMoreUtilities = true
        expensesByCategory = []
        utilityChargesByRoom = []
    }

    private func fetchData() async throws {
        async let fetchExpenses = financeService.fetchExpenses(
            propertyId: propertyId, startDate: startDate, endDate: endDate, limit: limit, offset: 0
        )
        async let fetchIncome = financeService.fetchIncome(
            propertyId: propertyId, startDate: startDate, endDate: endDate, limit: limit, offset: 0
        )
        async let fetchSummary = financeService.getFinancialSummary(
            propertyId: propertyId, year: selectedYear, month: selectedMonth
        )
        async let fetchUtilities = utilityService.fetchUtilityCharges(
            propertyId: propertyId, startDate: startDate, endDate: endDate, limit: limit, offset: 0
        )
        async let fetchUtilityConfig = utilityService.fetchPropertyUtilities(propertyId: propertyId)

        let newExpenses = try await fetchExpenses
        let newIncome = try await fetchIncome
        let newUtilities = try await fetchUtilities

        expenses = newExpenses
        income = newIncome
        utilityCharges = newUtilities
        summary = try await fetchSummary
        propertyUtilities = try await fetchUtilityConfig

        expensesByCategory = buildExpensesByCategory(from: expenses)
        utilityChargesByRoom = buildUtilityChargesByRoom(from: utilityCharges)

        expenseOffset = newExpenses.count
        incomeOffset = newIncome.count
        utilityOffset = newUtilities.count
        hasMoreExpenses = newExpenses.count == limit
        hasMoreIncome = newIncome.count == limit
        hasMoreUtilities = newUtilities.count == limit
    }

    /// Debounces realtime-triggered refreshes to avoid a request storm when
    /// multiple tables fire simultaneously.
    private nonisolated func scheduleRefresh() {
        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            await self.refreshData()
        }
    }

    private func refreshData() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let currentExpenseLimit = max(limit, expenses.count)
            let currentIncomeLimit = max(limit, income.count)
            let currentUtilityLimit = max(limit, utilityCharges.count)

            async let fetchExpenses = financeService.fetchExpenses(
                propertyId: propertyId, startDate: startDate, endDate: endDate,
                limit: currentExpenseLimit, offset: 0
            )
            async let fetchIncome = financeService.fetchIncome(
                propertyId: propertyId, startDate: startDate, endDate: endDate,
                limit: currentIncomeLimit, offset: 0
            )
            async let fetchSummary = financeService.getFinancialSummary(
                propertyId: propertyId, year: selectedYear, month: selectedMonth
            )
            async let fetchUtilities = utilityService.fetchUtilityCharges(
                propertyId: propertyId, startDate: startDate, endDate: endDate,
                limit: currentUtilityLimit, offset: 0
            )

            expenses = try await fetchExpenses
            income = try await fetchIncome
            summary = try await fetchSummary
            utilityCharges = try await fetchUtilities

            expensesByCategory = buildExpensesByCategory(from: expenses)
            utilityChargesByRoom = buildUtilityChargesByRoom(from: utilityCharges)

            expenseOffset = expenses.count
            incomeOffset = income.count
            utilityOffset = utilityCharges.count
        } catch {
            logger.error("Error refreshing finance data: \(error)")
        }
    }

    private func listenForChanges() async {
        let service = realtimeService
        let incomeStream = service.listenForChanges(table: SupabaseTable.income)
        let expensesStream = service.listenForChanges(table: SupabaseTable.expenses)
        let utilityStream = service.listenForChanges(table: SupabaseTable.utilityCharges)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in incomeStream { self.scheduleRefresh() }
            }
            group.addTask {
                for await _ in expensesStream { self.scheduleRefresh() }
            }
            group.addTask {
                for await _ in utilityStream { self.scheduleRefresh() }
            }
        }
    }

    // MARK: - Helpers

    private func buildExpensesByCategory(from expenses: [Expense]) -> [(category: String, amount: Decimal)] {
        Dictionary(grouping: expenses, by: \.category)
            .map { (category: $0.key, amount: $0.value.reduce(Decimal.zero) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }

    private func buildUtilityChargesByRoom(from charges: [UtilityCharge]) -> [(roomName: String, tenantName: String?, charges: [UtilityCharge])] {
        Dictionary(grouping: charges, by: \.roomId)
            .map { (_, charges) in
                let first = charges.first
                return (
                    roomName: first?.roomName
                        ?? String(localized: "Room", locale: LanguageService.currentLocale, comment: "Default room name"),
                    tenantName: first?.tenantName,
                    charges: charges.sorted {
                        ($0.type?.displayName ?? "") < ($1.type?.displayName ?? "")
                    }
                )
            }
            .sorted { $0.roomName < $1.roomName }
    }
}

enum FinanceSection: String, CaseIterable {
    case summary, expenses, income, utilities

    var displayName: String {
        switch self {
        case .summary: String(localized: "Summary", locale: LanguageService.currentLocale, comment: "Finance section")
        case .expenses: String(localized: "Expenses", locale: LanguageService.currentLocale, comment: "Finance section")
        case .income: String(localized: "Income", locale: LanguageService.currentLocale, comment: "Finance section")
        case .utilities:
            String(localized: "Utilities", locale: LanguageService.currentLocale, comment: "Finance section for utility bills")
        }
    }
}
