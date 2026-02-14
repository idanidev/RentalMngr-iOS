import Foundation

enum PropertyTab: String, CaseIterable {
    case rooms = "Habitaciones"
    case tenants = "Inquilinos"
    case finances = "Finanzas"
    case roomie = "Roomie"
}

@Observable
final class PropertyDetailViewModel {
    var property: Property
    var selectedTab: PropertyTab = .rooms
    var rooms: [Room] = []
    var tenants: [Tenant] = []
    var isLoading = false
    var errorMessage: String?

    private let propertyService: PropertyService
    private let roomService: RoomService
    private let tenantService: TenantService

    init(
        property: Property, propertyService: PropertyService, roomService: RoomService,
        tenantService: TenantService
    ) {
        self.property = property
        self.propertyService = propertyService
        self.roomService = roomService
        self.tenantService = tenantService
    }

    func loadData() async {
        isLoading = true
        do {
            // Fetch fresh rooms from API (not relying on potentially stale embedded data)
            rooms = try await roomService.fetchRooms(propertyId: property.id)
            property.rooms = rooms
            // Fetch tenants (they include their assigned room from join)
            tenants = try await tenantService.fetchTenants(propertyId: property.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Full refresh: re-fetch property with embedded rooms from Supabase
    func refreshData() async {
        isLoading = true
        do {
            let updated = try await propertyService.fetchProperty(id: property.id)
            property = updated
            rooms = updated.rooms ?? []
            tenants = try await tenantService.fetchTenants(propertyId: property.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var privateRooms: [Room] {
        property.privateRooms
    }

    var commonRooms: [Room] {
        property.commonRooms
    }

    var occupiedCount: Int {
        property.occupiedPrivateRooms.count
    }

    var vacantCount: Int {
        property.vacantPrivateRooms.count
    }

    var activeTenants: [Tenant] {
        tenants.filter(\.active)
    }
}
