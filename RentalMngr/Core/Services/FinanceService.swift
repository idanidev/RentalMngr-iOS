import Foundation
import Supabase

struct FinancialSummary: Sendable {
    let totalIncome: Decimal
    let paidIncome: Decimal
    let pendingIncome: Decimal
    let totalExpenses: Decimal
    var netProfit: Decimal { totalIncome - totalExpenses }
    let paidCount: Int
    let unpaidCount: Int
    var profitMargin: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(truncating: (netProfit / totalIncome * 100) as NSDecimalNumber)
    }
}

final class FinanceService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    /// The join select string for income with room name and tenant name
    private let incomeSelect = "*, room:room_id(id, name, tenant_name, tenant:tenant_id(full_name))"

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Expenses

    func fetchExpenses(propertyId: UUID, startDate: Date? = nil, endDate: Date? = nil) async throws
        -> [Expense]
    {
        var query =
            client
            .from("expenses")
            .select("*, property:properties(name), room:rooms(name)")
            .eq("property_id", value: propertyId)

        if let startDate {
            let dateStr = iso8601.string(from: startDate)
            query = query.gte("date", value: dateStr)
        }
        if let endDate {
            let dateStr = iso8601.string(from: endDate)
            query = query.lte("date", value: dateStr)
        }

        return
            try await query
            .order("date", ascending: false)
            .execute()
            .value
    }

    /// Group expenses by category and sum amounts (matches webapp getExpensesByCategory)
    func fetchExpensesByCategory(propertyId: UUID, startDate: Date? = nil, endDate: Date? = nil)
        async throws -> [(category: String, amount: Decimal)]
    {
        let expenses = try await fetchExpenses(
            propertyId: propertyId, startDate: startDate, endDate: endDate)
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped.map {
            (category: $0.key, amount: $0.value.reduce(Decimal.zero) { $0 + $1.amount })
        }
        .sorted { $0.amount > $1.amount }
    }

    func createExpense(
        propertyId: UUID, amount: Decimal, category: String, description: String?,
        date: Date, roomId: UUID?, createdBy: UUID
    ) async throws -> Expense {
        struct NewExpense: Encodable {
            let property_id: UUID
            let amount: Decimal
            let category: String
            let description: String?
            let date: Date
            let room_id: UUID?
            let created_by: UUID
        }
        return
            try await client
            .from("expenses")
            .insert(
                NewExpense(
                    property_id: propertyId, amount: amount, category: category,
                    description: description, date: date, room_id: roomId, created_by: createdBy)
            )
            .select()
            .single()
            .execute()
            .value
    }

    func updateExpense(_ expense: Expense) async throws -> Expense {
        struct UpdateExpense: Encodable {
            let amount: Decimal
            let category: String
            let description: String?
            let date: Date
            let room_id: UUID?
        }
        return
            try await client
            .from("expenses")
            .update(
                UpdateExpense(
                    amount: expense.amount, category: expense.category,
                    description: expense.description, date: expense.date, room_id: expense.roomId)
            )
            .eq("id", value: expense.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteExpense(id: UUID) async throws {
        try await client
            .from("expenses")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Income (WITH room join)

    func fetchIncome(propertyId: UUID, startDate: Date? = nil, endDate: Date? = nil) async throws
        -> [Income]
    {
        var query =
            client
            .from("income")
            .select(incomeSelect)
            .eq("property_id", value: propertyId)

        if let startDate {
            let dateStr = iso8601.string(from: startDate)
            query = query.gte("month", value: dateStr)
        }
        if let endDate {
            let dateStr = iso8601.string(from: endDate)
            query = query.lte("month", value: dateStr)
        }

        return
            try await query
            .order("month", ascending: false)
            .execute()
            .value
    }

    /// Fetch income for ALL given properties in a date range (for global finances view)
    func fetchAllIncome(propertyIds: [UUID], startDate: Date, endDate: Date) async throws
        -> [Income]
    {
        guard !propertyIds.isEmpty else { return [] }
        let startStr = iso8601.string(from: startDate)
        let endStr = iso8601.string(from: endDate)

        return
            try await client
            .from("income")
            .select(incomeSelect)
            .in("property_id", values: propertyIds.map(\.uuidString))
            .gte("month", value: startStr)
            .lte("month", value: endStr)
            .order("month", ascending: false)
            .execute()
            .value
    }

    func createIncome(propertyId: UUID, roomId: UUID, amount: Decimal, month: Date) async throws
        -> Income
    {
        struct NewIncome: Encodable {
            let property_id: UUID
            let room_id: UUID
            let amount: Decimal
            let month: Date
        }
        return
            try await client
            .from("income")
            .insert(
                NewIncome(property_id: propertyId, room_id: roomId, amount: amount, month: month)
            )
            .select(incomeSelect)
            .single()
            .execute()
            .value
    }

    func markAsPaid(incomeId: UUID) async throws {
        struct PaidUpdate: Encodable {
            let paid = true
            let payment_date: Date
        }
        try await client
            .from("income")
            .update(PaidUpdate(payment_date: Date()))
            .eq("id", value: incomeId)
            .execute()
    }

    func markAsUnpaid(incomeId: UUID) async throws {
        struct UnpaidUpdate: Encodable {
            let paid = false
            let payment_date: Date? = nil
        }
        try await client
            .from("income")
            .update(UnpaidUpdate())
            .eq("id", value: incomeId)
            .execute()
    }

    func deleteIncome(id: UUID) async throws {
        try await client
            .from("income")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Summary (matches webapp client-side calculation)

    func getFinancialSummary(propertyId: UUID, year: Int? = nil, month: Int? = nil) async throws
        -> FinancialSummary
    {
        var startDate: Date?
        var endDate: Date?

        if let year, let month {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            startDate = Calendar.current.date(from: components)

            if let start = startDate {
                endDate = Calendar.current.date(
                    byAdding: DateComponents(month: 1, second: -1), to: start)
            }
        }

        let capturedStart = startDate
        let capturedEnd = endDate
        async let expenses = fetchExpenses(
            propertyId: propertyId, startDate: capturedStart, endDate: capturedEnd)
        async let incomes = fetchIncome(
            propertyId: propertyId, startDate: capturedStart, endDate: capturedEnd)

        let expenseList = try await expenses
        let incomeList = try await incomes

        let totalExpenses = expenseList.reduce(Decimal.zero) { $0 + $1.amount }
        let totalIncome = incomeList.reduce(Decimal.zero) { $0 + $1.amount }
        let paidIncome = incomeList.filter(\.paid).reduce(Decimal.zero) { $0 + $1.amount }
        let pendingIncome = totalIncome - paidIncome
        let paidCount = incomeList.filter(\.paid).count
        let unpaidCount = incomeList.filter { !$0.paid }.count

        return FinancialSummary(
            totalIncome: totalIncome,
            paidIncome: paidIncome,
            pendingIncome: pendingIncome,
            totalExpenses: totalExpenses,
            paidCount: paidCount,
            unpaidCount: unpaidCount
        )
    }

    /// Triggers the automatic generation of monthly income via Supabase RPC
    func generateMonthlyIncome() async throws {
        try await client
            .rpc("generate_monthly_income")
            .execute()
    }
}
