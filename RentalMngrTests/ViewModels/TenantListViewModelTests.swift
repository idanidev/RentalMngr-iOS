import Testing
import Foundation
@testable import RentalMngr

@Suite("TenantListViewModel")
@MainActor
struct TenantListViewModelTests {

    private let propertyId = UUID()

    // MARK: - Initial state

    @Test("starts with empty state and showInactive false")
    func initialState() {
        let vm = makeVM()
        #expect(vm.tenants.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.showInactive == false)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - filteredTenants

    @Test("filteredTenants returns only active tenants by default")
    func filteredShowsOnlyActive() async {
        let service = MockTenantService()
        service.stubbedTenants = [
            makeTenant(active: true),
            makeTenant(active: false),
            makeTenant(active: true),
        ]
        let vm = makeVM(tenantService: service)
        await vm.loadTenants()

        #expect(vm.filteredTenants.count == 2)
    }

    @Test("filteredTenants returns all tenants when showInactive is true")
    func filteredShowsAllWhenShowInactive() async {
        let service = MockTenantService()
        service.stubbedTenants = [
            makeTenant(active: true),
            makeTenant(active: false),
        ]
        let vm = makeVM(tenantService: service)
        await vm.loadTenants()
        vm.showInactive = true

        #expect(vm.filteredTenants.count == 2)
    }

    // MARK: - loadTenants

    @Test("loadTenants populates tenants from service")
    func loadPopulatesTenants() async {
        let service = MockTenantService()
        service.stubbedTenants = [makeTenant(fullName: "Ana"), makeTenant(fullName: "Luis")]
        let vm = makeVM(tenantService: service)

        await vm.loadTenants()

        #expect(vm.tenants.count == 2)
        #expect(vm.isLoading == false)
    }

    @Test("loadTenants skips fetch when already loaded")
    func loadOnlyFetchesOnce() async {
        let service = MockTenantService()
        service.stubbedTenants = [makeTenant()]
        let vm = makeVM(tenantService: service)

        await vm.loadTenants()
        service.stubbedTenants = [makeTenant(), makeTenant(), makeTenant()]
        await vm.loadTenants()

        #expect(vm.tenants.count == 1)
    }

    @Test("loadTenants sets errorMessage on failure")
    func loadSetsErrorOnFailure() async {
        let service = MockTenantService()
        service.stubbedError = MockError.forced("timeout")
        let vm = makeVM(tenantService: service)

        await vm.loadTenants()

        #expect(vm.tenants.isEmpty)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - Pagination

    @Test("loadMore appends tenants to existing list")
    func loadMoreAppendsTenants() async {
        let service = MockTenantService()
        // 20 tenants to fill the first page, then 5 more
        service.stubbedTenants = (0..<25).map { i in makeTenant(fullName: "T\(i)") }
        let vm = makeVM(tenantService: service)

        await vm.loadTenants()
        #expect(vm.tenants.count == 20)
        #expect(vm.hasMoreData == true)

        await vm.loadMore()
        #expect(vm.tenants.count == 25)
    }

    @Test("loadMore sets hasMoreData false when last page returns fewer items")
    func loadMoreHasNoMoreDataOnLastPage() async {
        let service = MockTenantService()
        // 22 tenants: first page = 20, second page = 2 (< 20 → end)
        service.stubbedTenants = (0..<22).map { i in makeTenant(fullName: "T\(i)") }
        let vm = makeVM(tenantService: service)

        await vm.loadTenants()
        await vm.loadMore()

        #expect(vm.hasMoreData == false)
    }

    @Test("loadMore does nothing when hasMoreData is false")
    func loadMoreSkipsWhenNoMoreData() async {
        let service = MockTenantService()
        service.stubbedTenants = [makeTenant()]
        let vm = makeVM(tenantService: service)

        await vm.loadTenants()
        #expect(vm.hasMoreData == false)

        // Change stub to verify loadMore doesn't call service again
        service.stubbedTenants = (0..<20).map { _ in makeTenant() }
        await vm.loadMore()

        #expect(vm.tenants.count == 1)
    }

    // MARK: - refresh

    @Test("refresh resets and reloads tenants")
    func refreshReloads() async {
        let service = MockTenantService()
        service.stubbedTenants = [makeTenant()]
        let vm = makeVM(tenantService: service)

        await vm.loadTenants()
        service.stubbedTenants = [makeTenant(), makeTenant()]
        await vm.refresh()

        #expect(vm.tenants.count == 2)
    }

    // MARK: - deactivateTenant / reactivateTenant

    @Test("deactivateTenant calls service and refreshes")
    func deactivateCallsService() async {
        let service = MockTenantService()
        let tenant = makeTenant(active: true)
        service.stubbedTenants = [tenant]
        let vm = makeVM(tenantService: service)
        await vm.loadTenants()

        await vm.deactivateTenant(tenant)

        #expect(service.deactivateCallCount == 1)
    }

    @Test("reactivateTenant calls service")
    func reactivateCallsService() async {
        let service = MockTenantService()
        let tenant = makeTenant(active: false)
        service.stubbedTenants = [tenant]
        let vm = makeVM(tenantService: service)
        await vm.loadTenants()

        await vm.reactivateTenant(tenant)

        #expect(service.activateCallCount == 1)
    }

    @Test("deactivateTenant sets errorMessage when service fails")
    func deactivateErrorSetsMessage() async {
        let service = MockTenantService()
        let tenant = makeTenant(active: true)
        service.stubbedTenants = [tenant]
        let vm = makeVM(tenantService: service)
        await vm.loadTenants()

        service.stubbedError = MockError.forced("deactivate failed")
        await vm.deactivateTenant(tenant)

        #expect(vm.errorMessage != nil)
    }

    // MARK: - renewContract

    @Test("renewContract calls service with correct months")
    func renewContractCallsService() async {
        let service = MockTenantService()
        let tenant = makeTenant()
        service.stubbedTenants = [tenant]
        let vm = makeVM(tenantService: service)
        await vm.loadTenants()

        await vm.renewContract(tenant: tenant, months: 12)

        #expect(service.renewCallCount == 1)
    }
}

// MARK: - Helpers

@MainActor
private func makeVM(
    tenantService: MockTenantService = MockTenantService(),
    roomService: MockRoomService = MockRoomService(),
    realtimeService: MockRealtimeService = MockRealtimeService(),
    propertyId: UUID = UUID()
) -> TenantListViewModel {
    TenantListViewModel(
        propertyId: propertyId,
        tenantService: tenantService,
        roomService: roomService,
        realtimeService: realtimeService
    )
}
