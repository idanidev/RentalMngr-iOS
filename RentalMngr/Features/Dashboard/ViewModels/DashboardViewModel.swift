import Foundation

@Observable
final class DashboardViewModel {
    var properties: [Property] = []
    var totalRooms = 0
    var occupiedRooms = 0
    var totalMonthlyIncome: Decimal = 0
    var pendingPayments = 0
    var expiringContracts: [Tenant] = []
    var isLoading = false
    var errorMessage: String?

    private let propertyService: PropertyService
    private let roomService: RoomService
    private let tenantService: TenantService
    private let financeService: FinanceService

    init(propertyService: PropertyService, roomService: RoomService,
         tenantService: TenantService, financeService: FinanceService) {
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
        isLoading = true
        errorMessage = nil

        do {
            // Properties already include embedded rooms via join query
            properties = try await propertyService.fetchProperties()

            // Calculate stats from embedded rooms (like webapp does)
            var rooms = 0
            var occupied = 0
            var monthlyIncome: Decimal = 0
            var pending = 0

            for property in properties {
                let privateRooms = property.privateRooms
                rooms += privateRooms.count
                occupied += property.occupiedPrivateRooms.count
                monthlyIncome += property.monthlyRevenue

                // Still need to query income to count pending payments
                let income = try await financeService.fetchIncome(propertyId: property.id)
                pending += income.filter { !$0.paid }.count
            }

            totalRooms = rooms
            occupiedRooms = occupied
            totalMonthlyIncome = monthlyIncome
            pendingPayments = pending

            expiringContracts = try await tenantService.getExpiringContracts(daysAhead: 30)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
