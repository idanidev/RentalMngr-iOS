import Foundation

@Observable
final class TenantListViewModel {
    var tenants: [Tenant] = []
    var showInactive = false
    var isLoading = false
    var errorMessage: String?
    let propertyId: UUID

    private let tenantService: TenantService
    private let roomService: RoomService

    init(propertyId: UUID, tenantService: TenantService, roomService: RoomService) {
        self.propertyId = propertyId
        self.tenantService = tenantService
        self.roomService = roomService
    }

    var filteredTenants: [Tenant] {
        showInactive ? tenants : tenants.filter(\.active)
    }

    func loadTenants() async {
        isLoading = true
        errorMessage = nil
        do {
            print("[TenantListVM] Loading tenants for propertyId: \(propertyId)")
            tenants = try await tenantService.fetchTenants(propertyId: propertyId)
            print(
                "[TenantListVM] Loaded \(tenants.count) tenants, active: \(tenants.filter(\.active).count)"
            )
            for t in tenants {
                print(
                    "[TenantListVM]   - \(t.fullName) active=\(t.active) room=\(t.room?.name ?? "none")"
                )
            }
        } catch {
            print("[TenantListVM] ERROR loading tenants: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deactivateTenant(_ tenant: Tenant) async {
        do {
            try await tenantService.deactivateTenant(id: tenant.id)
            await loadTenants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkIn(tenantId: UUID, roomId: UUID) async {
        do {
            try await tenantService.assignToRoom(tenantId: tenantId, roomId: roomId)
            await loadTenants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkOut(roomId: UUID) async {
        do {
            try await tenantService.unassignFromRoom(roomId: roomId)
            await loadTenants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    func renewContract(tenant: Tenant, months: Int) async {
        do {
            try await tenantService.renewContract(tenantId: tenant.id, contractMonths: months)
            await loadTenants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
