import Foundation

@MainActor @Observable
final class RoomListViewModel {
    var rooms: [Room] = []
    var isLoading = false
    private(set) var isLoaded = false
    var errorMessage: String?
    let propertyId: UUID

    private let roomService: RoomServiceProtocol
    private let tenantService: TenantServiceProtocol

    init(
        propertyId: UUID, roomService: RoomServiceProtocol, tenantService: TenantServiceProtocol,
        rooms: [Room]
    ) {
        self.propertyId = propertyId
        self.roomService = roomService
        self.tenantService = tenantService
        self.rooms = rooms
    }

    func loadRooms() async {
        guard !isLoaded else { return }
        isLoading = true
        errorMessage = nil
        do {
            var fetchedRooms = try await roomService.fetchRooms(propertyId: propertyId)
            let activeTenants = try await tenantService.fetchActiveTenants(propertyId: propertyId)

            let tenantByRoomId = Dictionary(
                uniqueKeysWithValues: activeTenants.compactMap { tenant -> (UUID, Tenant)? in
                    guard let roomId = tenant.room?.id else { return nil }
                    return (roomId, tenant)
                }
            )
            for i in fetchedRooms.indices {
                if let tenant = tenantByRoomId[fetchedRooms[i].id] {
                    fetchedRooms[i].tenantName = tenant.fullName
                    fetchedRooms[i].tenantId = tenant.id
                    fetchedRooms[i].occupied = true
                }
            }
            rooms = fetchedRooms
        } catch where error.isCancellation || Task.isCancelled {
            // Tarea cancelada por navegación — no es un error real
            isLoading = false
            return
        } catch {
            errorMessage = error.safeUserMessage
        }
        isLoaded = true
        isLoading = false
    }

    func refresh() async {
        isLoaded = false
        await loadRooms()
    }

    func deleteRoom(_ room: Room) async {
        do {
            try await roomService.deleteRoom(id: room.id)
            rooms.removeAll { $0.id == room.id }
        } catch where error.isCancellation || Task.isCancelled {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.safeUserMessage
        }
    }

    /// Qué significa "marcar como libre" para esta habitación.
    ///
    /// Con un inquilino asignado no basta con cambiar la marca: la lista deduce
    /// la ocupación del inquilino, así que la habitación seguía saliendo ocupada
    /// y el botón parecía no hacer nada (#25). Dejarla libre de verdad es darle
    /// salida al inquilino.
    enum VacateAction: Equatable { case toggle, checkOut }

    static func vacateAction(for room: Room) -> VacateAction {
        room.occupied && room.tenantId != nil ? .checkOut : .toggle
    }

    /// Da salida al inquilino y deja la habitación libre. No borra nada: su
    /// ficha, su contrato y sus pagos se quedan; solo deja de estar asignado.
    func checkOut(_ room: Room) async {
        do {
            try await tenantService.unassignFromRoom(roomId: room.id)
            await refresh()
        } catch where error.isCancellation || Task.isCancelled {
            return
        } catch {
            errorMessage = error.safeUserMessage
        }
    }

    func toggleOccupancy(_ room: Room) async {
        do {
            try await roomService.toggleOccupancy(roomId: room.id, occupied: !room.occupied)
            await refresh()
        } catch where error.isCancellation || Task.isCancelled {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.safeUserMessage
        }
    }

    var privateRooms: [Room] {
        rooms.filter { $0.roomType == .privateRoom }
    }

    var commonRooms: [Room] {
        rooms.filter { $0.roomType == .common }
    }
}
