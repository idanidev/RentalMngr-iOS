import Foundation

@MainActor @Observable
final class DashboardViewModel {
    var properties: [Property] = []
    var totalRooms = 0
    var occupiedRooms = 0
    var totalMonthlyIncome: Decimal = 0
    var collectedIncome: Decimal = 0
    var pendingPayments = 0
    var expiringContracts: [Tenant] = []
    var isLoading = false
    private(set) var isLoaded = false
    var errorMessage: String?

    private let propertyService: PropertyServiceProtocol
    private let roomService: RoomServiceProtocol
    private let tenantService: TenantServiceProtocol
    private let financeService: FinanceServiceProtocol

    init(
        propertyService: PropertyServiceProtocol, roomService: RoomServiceProtocol,
        tenantService: TenantServiceProtocol, financeService: FinanceServiceProtocol
    ) {
        self.propertyService = propertyService
        self.roomService = roomService
        self.tenantService = tenantService
        self.financeService = financeService
    }

    var occupancyRate: Double {
        guard totalRooms > 0 else { return 0 }
        return Double(occupiedRooms) / Double(totalRooms) * 100
    }

    func loadDashboard() async {
        guard !isLoaded else { return }
        isLoading = true
        errorMessage = nil

        do {
            // Properties already include embedded rooms via join query
            properties = try await propertyService.fetchProperties()

            // Calculate stats from embedded rooms (like webapp does)
            var rooms = 0
            var occupied = 0
            var monthlyIncome: Decimal = 0

            for property in properties {
                let privateRooms = property.privateRooms
                rooms += privateRooms.count
                occupied += property.occupiedPrivateRooms.count
                monthlyIncome += property.monthlyRevenue
            }

            totalRooms = rooms
            occupiedRooms = occupied
            totalMonthlyIncome = monthlyIncome

            // Batch fetch ALL income in a single query (fixes N+1)
            let now = Date()
            let calendar = Calendar.current
            let startOfMonth =
                calendar.date(
                    from: calendar.dateComponents([.year, .month], from: now))
                ?? now
            let endOfMonth =
                calendar.date(
                    byAdding: DateComponents(month: 1, second: -1), to: startOfMonth)
                ?? now
            let allIncome = try await financeService.fetchAllIncome(
                propertyIds: properties.map(\.id),
                startDate: startOfMonth,
                endDate: endOfMonth
            )
            pendingPayments = allIncome.filter { !$0.paid }.count
            collectedIncome = allIncome.filter { $0.paid }.reduce(Decimal.zero) { $0 + $1.amount }

            expiringContracts = try await tenantService.getExpiringContracts(daysAhead: 30)
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isLoading = false
            return
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoaded = true
        isLoading = false
    }

    func refresh() async {
        isLoaded = false
        await loadDashboard()
    }
}
