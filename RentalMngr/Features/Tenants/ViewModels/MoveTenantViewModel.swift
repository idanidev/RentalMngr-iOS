import Foundation

@MainActor @Observable
final class MoveTenantViewModel {
    var availableRooms: [Room] = []
    var selectedRoomId: UUID?
    var isLoading = false
    var errorMessage: String?
    var isSaving = false

    private let tenant: Tenant
    private let roomService: RoomServiceProtocol
    private let tenantService: TenantServiceProtocol
    private let propertyId: UUID

    var isValid: Bool {
        selectedRoomId != nil && selectedRoomId != tenant.room?.id
    }

    init(
        tenant: Tenant,
        propertyId: UUID,
        roomService: RoomServiceProtocol,
        tenantService: TenantServiceProtocol
    ) {
        self.tenant = tenant
        self.propertyId = propertyId
        self.roomService = roomService
        self.tenantService = tenantService
        // Pre-select current room if any
        self.selectedRoomId = tenant.room?.id
    }

    func loadRooms() async {
        isLoading = true
        errorMessage = nil
        do {
            let rooms = try await roomService.fetchRooms(propertyId: propertyId)
            // Filter: show empty rooms OR current room
            self.availableRooms = rooms.filter { !$0.occupied || $0.id == tenant.room?.id }
        } catch {
            errorMessage = String(localized: "Error loading rooms: \(error.localizedDescription)", locale: LanguageService.currentLocale, comment: "Error message when rooms fail to load")
        }
        isLoading = false
    }

    func moveTenant() async -> Bool {
        guard let targetRoomId = selectedRoomId else { return false }
        isSaving = true
        errorMessage = nil

        do {
            _ = try await tenantService.moveTenant(tenant: tenant, toRoomId: targetRoomId)
            isSaving = false
            return true
        } catch {
            errorMessage = String(localized: "Error moving tenant: \(error.localizedDescription)", locale: LanguageService.currentLocale, comment: "Error message when tenant move fails")
            isSaving = false
            return false
        }
    }
}
