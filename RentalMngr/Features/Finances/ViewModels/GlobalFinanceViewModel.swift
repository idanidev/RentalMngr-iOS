import Foundation
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "GlobalFinanceVM")

/// Groups income + utility charge data across all properties for the global finance view
@MainActor @Observable
final class GlobalFinanceViewModel {
    var properties: [Property] = []
    var incomeByProperty: [UUID: [Income]] = [:]
    var utilityChargesByProperty: [UUID: [UtilityCharge]] = [:]
    var isLoading = false
    private(set) var isLoaded = false
    var errorMessage: String?
    /// Error from a paid/unpaid toggle — shown as an alert, not the full-screen error state
    var actionErrorMessage: String?
    // Default to previous month — finances are reviewed "mes vencido" (month in arrears)
    @ObservationIgnored
    private var _selectedDate: Date =
        UserDefaults.standard.object(forKey: "finance.global.selectedDate") as? Date
        ?? Calendar.current.date(byAdding: .month, value: -1, to: Date())
        ?? Date()
    var selectedDate: Date {
        get {
            access(keyPath: \.selectedDate)
            return _selectedDate
        }
        set {
            withMutation(keyPath: \.selectedDate) {
                _selectedDate = newValue
                UserDefaults.standard.set(newValue, forKey: "finance.global.selectedDate")
            }
        }
    }
    private(set) var propertiesWithIncome: [Property] = []
    private(set) var paymentsByPropertyAndRoom: [UUID: [RoomPaymentGroup]] = [:]

    private let propertyService: PropertyServiceProtocol
    private let financeService: FinanceServiceProtocol
    private let utilityService: UtilityServiceProtocol
    private let realtimeService: RealtimeServiceProtocol
    @ObservationIgnored
    nonisolated(unsafe) private var realtimeTask: Task<Void, Never>?
    @ObservationIgnored private var refreshDebounceTask: Task<Void, Never>?
    private var isRefreshing = false

    init(
        propertyService: PropertyServiceProtocol,
        financeService: FinanceServiceProtocol,
        utilityService: UtilityServiceProtocol,
        realtimeService: RealtimeServiceProtocol
    ) {
        self.propertyService = propertyService
        self.financeService = financeService
        self.utilityService = utilityService
        self.realtimeService = realtimeService
    }

    nonisolated deinit {
        realtimeTask?.cancel()
    }

    // MARK: - Computed

    var totalExpected: Decimal {
        let incomeTotal = incomeByProperty.values.flatMap { $0 }.reduce(Decimal.zero) { $0 + $1.amount }
        let utilityTotal = utilityChargesByProperty.values.flatMap { $0 }.reduce(Decimal.zero) { $0 + $1.amount }
        return incomeTotal + utilityTotal
    }

    var totalPaid: Decimal {
        let incomePaid = incomeByProperty.values.flatMap { $0 }.filter(\.paid).reduce(Decimal.zero) { $0 + $1.amount }
        let utilityPaid = utilityChargesByProperty.values.flatMap { $0 }.filter(\.paid).reduce(Decimal.zero) { $0 + $1.amount }
        return incomePaid + utilityPaid
    }

    var totalPending: Decimal {
        totalExpected - totalPaid
    }

    var paidCount: Int {
        let incomePaid = incomeByProperty.values.flatMap { $0 }.filter(\.paid).count
        let utilityPaid = utilityChargesByProperty.values.flatMap { $0 }.filter(\.paid).count
        return incomePaid + utilityPaid
    }

    var unpaidCount: Int {
        let incomeUnpaid = incomeByProperty.values.flatMap { $0 }.filter { !$0.paid }.count
        let utilityUnpaid = utilityChargesByProperty.values.flatMap { $0 }.filter { !$0.paid }.count
        return incomeUnpaid + utilityUnpaid
    }

    func incomeForProperty(_ propertyId: UUID) -> [Income] {
        (incomeByProperty[propertyId] ?? []).sorted { a, b in
            // Unpaid first, then by room name
            if a.paid != b.paid { return !a.paid }
            return (a.room?.name ?? "") < (b.room?.name ?? "")
        }
    }

    func utilityChargesForProperty(_ propertyId: UUID) -> [UtilityCharge] {
        (utilityChargesByProperty[propertyId] ?? []).sorted { a, b in
            // Sort by room, then by utility type
            let roomA = a.room?.name ?? ""
            let roomB = b.room?.name ?? ""
            if roomA != roomB { return roomA < roomB }
            return a.utilityType < b.utilityType
        }
    }

    /// Group income + utilities by room for a property, showing rent + utilities under each tenant
    private func computePaymentsByRoom(for propertyId: UUID) -> [RoomPaymentGroup] {
        let income = incomeForProperty(propertyId)
        let utilities = utilityChargesForProperty(propertyId)

        // Build groups by roomId
        var roomGroups: [UUID: RoomPaymentGroup] = [:]

        for item in income {
            let roomId = item.roomId
            if roomGroups[roomId] == nil {
                roomGroups[roomId] = RoomPaymentGroup(
                    roomId: roomId,
                    roomName: item.roomName,
                    tenantName: item.tenantName,
                    rent: item,
                    utilities: []
                )
            } else {
                roomGroups[roomId]?.rent = item
            }
        }

        for charge in utilities {
            let roomId = charge.roomId
            if roomGroups[roomId] == nil {
                roomGroups[roomId] = RoomPaymentGroup(
                    roomId: roomId,
                    roomName: charge.roomName,
                    tenantName: charge.tenantName,
                    rent: nil,
                    utilities: [charge]
                )
            } else {
                roomGroups[roomId]?.utilities.append(charge)
            }
        }

        return roomGroups.values.sorted { a, b in
            // Rooms with unpaid items first
            let aHasUnpaid = !(a.rent?.paid ?? true) || a.utilities.contains { !$0.paid }
            let bHasUnpaid = !(b.rent?.paid ?? true) || b.utilities.contains { !$0.paid }
            if aHasUnpaid != bHasUnpaid { return aHasUnpaid }
            return a.roomName < b.roomName
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        guard !isLoaded else { return }
        isLoading = true
        errorMessage = nil
        propertiesWithIncome = []
        paymentsByPropertyAndRoom = [:]

        // Start listening only once
        if realtimeTask == nil {
            realtimeTask = Task { [weak self] in
                guard let self else { return }
                await self.listenForChanges()
            }
        }

        do {
            // Fetch all properties
            properties = try await propertyService.fetchProperties()

            // Auto-generate utility charges only for the current month — merely viewing a
            // future month must not write real utility_charges rows.
            if isCurrentMonth(selectedDate) {
                try? await utilityService.generateMonthlyUtilityCharges(
                    properties: properties, month: selectedDate)
            }

            // Calculate month range
            let (startOfMonth, endOfMonth) = monthRange(for: selectedDate)
            let propertyIds = properties.map(\.id)

            // Fetch income and utility charges in parallel
            async let fetchIncome = financeService.fetchAllIncome(
                propertyIds: propertyIds,
                startDate: startOfMonth,
                endDate: endOfMonth
            )
            async let fetchUtilities = utilityService.fetchAllUtilityCharges(
                propertyIds: propertyIds,
                startDate: startOfMonth,
                endDate: endOfMonth
            )

            let allIncome = try await fetchIncome
            let allUtilities = try await fetchUtilities

            // Group by property. Hide vacant rooms: the server RPC generates rent for every
            // room, but a room with no active tenant (tenantName == nil) should not appear.
            incomeByProperty = Dictionary(grouping: visibleIncome(allIncome), by: \.propertyId)
            utilityChargesByProperty = Dictionary(grouping: allUtilities, by: \.propertyId)

            // Populate stored derived properties
            propertiesWithIncome = properties.sorted { $0.name < $1.name }
            paymentsByPropertyAndRoom = [:]
            for property in properties {
                paymentsByPropertyAndRoom[property.id] = computePaymentsByRoom(for: property.id)
            }

        } catch where error.isCancellation || Task.isCancelled {
            // Tarea cancelada por navegación — no es un error real
            isLoading = false
            return
        } catch {
            errorMessage = error.safeUserMessage
            logger.error("[GlobalFinanceVM] Error: \(error)")
        }

        isLoaded = true
        isLoading = false
    }

    func refresh() async {
        isLoaded = false
        await loadData()
    }

    private func listenForChanges() async {
        let service = realtimeService
        let incomeStream = service.listenForChanges(table: SupabaseTable.income)
        let propertiesStream = service.listenForChanges(table: SupabaseTable.properties)
        let utilityStream = service.listenForChanges(table: SupabaseTable.utilityCharges)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in incomeStream { await self.scheduleRefresh() }
            }
            group.addTask {
                for await _ in propertiesStream { await self.scheduleRefresh() }
            }
            group.addTask {
                for await _ in utilityStream { await self.scheduleRefresh() }
            }
        }
    }

    /// Coalesce a burst of realtime events (e.g. monthly-charge generation fires one event
    /// per room×utility) into a single refresh, so we don't issue a storm of full re-fetches.
    private func scheduleRefresh() {
        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            await self.refreshData()
        }
    }

    /// Check if a date is in the current month
    private func isCurrentMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    /// True if `date` is in the current month or a later one (not a past month).
    private func isCurrentOrFutureMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let monthOf: (Date) -> Date = { calendar.date(from: calendar.dateComponents([.year, .month], from: $0)) ?? $0 }
        return monthOf(date) >= monthOf(Date())
    }

    /// Income visible in the month view for `selectedDate`.
    ///
    /// The server RPC auto-generates a rent row for every room of the current/
    /// future month, including vacant ones. We hide those phantom rows (a room
    /// with no active tenant, still unpaid) so a vacant room doesn't show fake
    /// rent. But that filter must NOT touch real history: past-month income and
    /// any collected (paid) income are always shown — otherwise a tenant who has
    /// since checked out makes their real income vanish from the month and its
    /// totals (which disagreed with the annual report).
    private func visibleIncome(_ income: [Income]) -> [Income] {
        guard isCurrentOrFutureMonth(selectedDate) else { return income }
        return income.filter { $0.paid || $0.tenantName != nil }
    }

    /// Safe month range calculation
    private func monthRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let startOfMonth = calendar.date(from: components) ?? date
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth) ?? date
        return (startOfMonth, endOfMonth)
    }

    private func refreshData() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            properties = try await propertyService.fetchProperties()
            let (startOfMonth, endOfMonth) = monthRange(for: selectedDate)
            let propertyIds = properties.map(\.id)

            async let fetchIncome = financeService.fetchAllIncome(
                propertyIds: propertyIds,
                startDate: startOfMonth,
                endDate: endOfMonth
            )
            async let fetchUtilities = utilityService.fetchAllUtilityCharges(
                propertyIds: propertyIds,
                startDate: startOfMonth,
                endDate: endOfMonth
            )

            incomeByProperty = Dictionary(grouping: visibleIncome(try await fetchIncome), by: \.propertyId)
            utilityChargesByProperty = Dictionary(grouping: try await fetchUtilities, by: \.propertyId)

            // Repopulate stored derived properties
            propertiesWithIncome = properties.sorted { $0.name < $1.name }
            paymentsByPropertyAndRoom = [:]
            for property in properties {
                paymentsByPropertyAndRoom[property.id] = computePaymentsByRoom(for: property.id)
            }
        } catch {
            logger.error("[GlobalFinanceVM] Error refreshing: \(error)")
        }
    }

    func changeMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedDate) {
            selectedDate = newDate
            Task { await refresh() }
        }
    }

    // MARK: - Actions

    func markAsPaid(_ income: Income) async {
        do {
            try await financeService.markAsPaid(incomeId: income.id)
            updateIncomeInPlace(id: income.id, propertyId: income.propertyId, paid: true, paymentDate: Date())
        } catch {
            logger.error("[GlobalFinanceVM] Error marking paid: \(error)")
            actionErrorMessage = error.safeUserMessage
        }
    }

    func markAsUnpaid(_ income: Income) async {
        do {
            try await financeService.markAsUnpaid(incomeId: income.id)
            updateIncomeInPlace(id: income.id, propertyId: income.propertyId, paid: false, paymentDate: nil)
        } catch {
            logger.error("[GlobalFinanceVM] Error marking unpaid: \(error)")
            actionErrorMessage = error.safeUserMessage
        }
    }

    func markUtilityPaid(_ charge: UtilityCharge) async {
        do {
            try await utilityService.markUtilityPaid(chargeId: charge.id)
            updateUtilityInPlace(id: charge.id, propertyId: charge.propertyId, paid: true, paymentDate: Date())
        } catch {
            logger.error("[GlobalFinanceVM] Error marking utility paid: \(error)")
            actionErrorMessage = error.safeUserMessage
        }
    }

    func markUtilityUnpaid(_ charge: UtilityCharge) async {
        do {
            try await utilityService.markUtilityUnpaid(chargeId: charge.id)
            updateUtilityInPlace(id: charge.id, propertyId: charge.propertyId, paid: false, paymentDate: nil)
        } catch {
            logger.error("[GlobalFinanceVM] Error marking utility unpaid: \(error)")
            actionErrorMessage = error.safeUserMessage
        }
    }

    /// Mutates income paid state in-place without resorting — keeps rows in their current position.
    private func updateIncomeInPlace(id: UUID, propertyId: UUID, paid: Bool, paymentDate: Date?) {
        // Update source array
        if var list = incomeByProperty[propertyId],
           let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx].paid = paid
            list[idx].paymentDate = paymentDate
            incomeByProperty[propertyId] = list
        }
        // Update derived groups in-place — no reorder
        if var groups = paymentsByPropertyAndRoom[propertyId],
           let groupIdx = groups.firstIndex(where: { $0.rent?.id == id }) {
            groups[groupIdx].rent?.paid = paid
            groups[groupIdx].rent?.paymentDate = paymentDate
            paymentsByPropertyAndRoom[propertyId] = groups
        }
    }

    /// Mutates utility paid state in-place without resorting — keeps rows in their current position.
    private func updateUtilityInPlace(id: UUID, propertyId: UUID, paid: Bool, paymentDate: Date?) {
        // Update source array
        if var list = utilityChargesByProperty[propertyId],
           let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx].paid = paid
            list[idx].paymentDate = paymentDate
            utilityChargesByProperty[propertyId] = list
        }
        // Update derived groups in-place — no reorder
        if var groups = paymentsByPropertyAndRoom[propertyId],
           let groupIdx = groups.firstIndex(where: { $0.utilities.contains { $0.id == id } }),
           let chargeIdx = groups[groupIdx].utilities.firstIndex(where: { $0.id == id }) {
            groups[groupIdx].utilities[chargeIdx].paid = paid
            groups[groupIdx].utilities[chargeIdx].paymentDate = paymentDate
            paymentsByPropertyAndRoom[propertyId] = groups
        }
    }

    // MARK: - Formatting

    var monthYearLabel: String {
        selectedDate.formatted(.dateTime.month(.wide).year()).capitalized
    }
}

/// Groups rent + utility charges for a single room/tenant
struct RoomPaymentGroup: Identifiable {
    let roomId: UUID
    let roomName: String
    let tenantName: String?
    var rent: Income?
    var utilities: [UtilityCharge]

    var id: UUID { roomId }

    var allPaid: Bool {
        let rentPaid = rent?.paid ?? true
        let utilitiesPaid = utilities.allSatisfy(\.paid)
        return rentPaid && utilitiesPaid
    }

    var totalItems: Int {
        (rent != nil ? 1 : 0) + utilities.count
    }

    var paidItems: Int {
        (rent?.paid == true ? 1 : 0) + utilities.filter(\.paid).count
    }
}
