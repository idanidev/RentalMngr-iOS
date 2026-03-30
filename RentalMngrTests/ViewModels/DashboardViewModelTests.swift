import Testing
import Foundation
@testable import RentalMngr

@Suite("DashboardViewModel")
@MainActor
struct DashboardViewModelTests {

    // MARK: - Initial state

    @Test("starts empty and not loading")
    func initialState() {
        let vm = makeVM()
        #expect(vm.properties.isEmpty)
        #expect(vm.totalRooms == 0)
        #expect(vm.occupiedRooms == 0)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("occupancyRate is 0 when no rooms loaded")
    func occupancyRateInitiallyZero() {
        let vm = makeVM()
        #expect(vm.occupancyRate == 0)
    }

    // MARK: - loadDashboard — room aggregation

    @Test("loadDashboard counts all private rooms across properties")
    func loadCountsRooms() async {
        let propertyService = MockPropertyService()
        propertyService.stubbedProperties = [
            makeProperty(rooms: [
                makeRoom(type: .privateRoom),
                makeRoom(type: .privateRoom),
                makeRoom(type: .common),  // should not count
            ]),
            makeProperty(rooms: [
                makeRoom(type: .privateRoom),
            ]),
        ]
        let vm = makeVM(propertyService: propertyService)

        await vm.loadDashboard()

        #expect(vm.totalRooms == 3)
    }

    @Test("loadDashboard counts only occupied private rooms")
    func loadCountsOccupiedRooms() async {
        let propertyService = MockPropertyService()
        propertyService.stubbedProperties = [
            makeProperty(rooms: [
                makeRoom(type: .privateRoom, occupied: true),
                makeRoom(type: .privateRoom, occupied: false),
                makeRoom(type: .common, occupied: true), // should not count
            ]),
        ]
        let vm = makeVM(propertyService: propertyService)

        await vm.loadDashboard()

        #expect(vm.occupiedRooms == 1)
    }

    @Test("loadDashboard computes total monthly income from occupied rooms")
    func loadComputesMonthlyIncome() async {
        let propertyService = MockPropertyService()
        propertyService.stubbedProperties = [
            makeProperty(rooms: [
                makeRoom(type: .privateRoom, occupied: true, rent: 600),
                makeRoom(type: .privateRoom, occupied: true, rent: 400),
                makeRoom(type: .privateRoom, occupied: false, rent: 500), // vacant
            ]),
        ]
        let vm = makeVM(propertyService: propertyService)

        await vm.loadDashboard()

        #expect(vm.totalMonthlyIncome == 1000)
    }

    @Test("occupancyRate is correct after load")
    func occupancyRateAfterLoad() async {
        let propertyService = MockPropertyService()
        propertyService.stubbedProperties = [
            makeProperty(rooms: [
                makeRoom(type: .privateRoom, occupied: true),
                makeRoom(type: .privateRoom, occupied: false),
                makeRoom(type: .privateRoom, occupied: false),
                makeRoom(type: .privateRoom, occupied: false),
            ]),
        ]
        let vm = makeVM(propertyService: propertyService)

        await vm.loadDashboard()

        // 1/4 occupied = 25%
        #expect(vm.occupancyRate == 25.0)
    }

    // MARK: - loadDashboard — income/payments aggregation

    @Test("loadDashboard counts pending (unpaid) payments from finance service")
    func loadCountsPendingPayments() async {
        let financeService = MockFinanceService()
        financeService.stubbedIncome = [
            makeIncome(paid: false),
            makeIncome(paid: false),
            makeIncome(paid: true),
        ]
        let vm = makeVM(financeService: financeService)

        await vm.loadDashboard()

        #expect(vm.pendingPayments == 2)
    }

    @Test("loadDashboard sums only paid income for collectedIncome")
    func loadSumsPaidIncome() async {
        let financeService = MockFinanceService()
        financeService.stubbedIncome = [
            makeIncome(amount: 600, paid: true),
            makeIncome(amount: 400, paid: true),
            makeIncome(amount: 500, paid: false),
        ]
        let vm = makeVM(financeService: financeService)

        await vm.loadDashboard()

        #expect(vm.collectedIncome == 1000)
    }

    // MARK: - loadDashboard — expiring contracts

    @Test("loadDashboard loads expiring contracts from tenant service")
    func loadExpiringContracts() async {
        let tenantService = MockTenantService()
        tenantService.stubbedExpiringContracts = [
            makeTenant(fullName: "Juan"),
            makeTenant(fullName: "María"),
        ]
        let vm = makeVM(tenantService: tenantService)

        await vm.loadDashboard()

        #expect(vm.expiringContracts.count == 2)
    }

    // MARK: - guard !isLoaded

    @Test("loadDashboard skips fetch when already loaded")
    func loadOnlyFetchesOnce() async {
        let propertyService = MockPropertyService()
        propertyService.stubbedProperties = [makeProperty()]
        let vm = makeVM(propertyService: propertyService)

        await vm.loadDashboard()
        propertyService.stubbedProperties = [makeProperty(), makeProperty(), makeProperty()]
        await vm.loadDashboard()

        // Still 0 rooms from first load (property had no rooms embedded)
        #expect(vm.properties.count == 1)
    }

    // MARK: - Error handling

    @Test("loadDashboard sets errorMessage when property service fails")
    func loadSetsErrorOnFailure() async {
        let propertyService = MockPropertyService()
        propertyService.stubbedError = MockError.forced("server down")
        let vm = makeVM(propertyService: propertyService)

        await vm.loadDashboard()

        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadDashboard sets errorMessage when finance service fails")
    func loadSetsErrorOnFinanceFailure() async {
        let propertyService = MockPropertyService()
        propertyService.stubbedProperties = [makeProperty()]
        let financeService = MockFinanceService()
        financeService.stubbedError = MockError.forced("finance error")
        let vm = makeVM(propertyService: propertyService, financeService: financeService)

        await vm.loadDashboard()

        #expect(vm.errorMessage != nil)
    }

    // MARK: - refresh

    @Test("refresh resets state and fetches new data")
    func refreshUpdatesData() async {
        let propertyService = MockPropertyService()
        propertyService.stubbedProperties = [makeProperty(rooms: [makeRoom(type: .privateRoom)])]
        let vm = makeVM(propertyService: propertyService)

        await vm.loadDashboard()
        #expect(vm.totalRooms == 1)

        propertyService.stubbedProperties = [
            makeProperty(rooms: [makeRoom(type: .privateRoom), makeRoom(type: .privateRoom)])
        ]
        await vm.refresh()

        #expect(vm.totalRooms == 2)
    }
}

// MARK: - Helpers

@MainActor
private func makeVM(
    propertyService: MockPropertyService = MockPropertyService(),
    roomService: MockRoomService = MockRoomService(),
    tenantService: MockTenantService = MockTenantService(),
    financeService: MockFinanceService = MockFinanceService()
) -> DashboardViewModel {
    DashboardViewModel(
        propertyService: propertyService,
        roomService: roomService,
        tenantService: tenantService,
        financeService: financeService
    )
}
