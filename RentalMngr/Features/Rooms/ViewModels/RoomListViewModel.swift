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
        await loadRooms()
    }

    func deleteRoom(_ room: Room) async {
        do {
            try await roomService.deleteRoom(id: room.id)
            rooms.removeAll { $0.id == room.id }
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleOccupancy(_ room: Room) async {
        do {
            try await roomService.toggleOccupancy(roomId: room.id, occupied: !room.occupied)
            await refresh()
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var privateRooms: [Room] {
        rooms.filter { $0.roomType == .privateRoom }
    }

    var commonRooms: [Room] {
        rooms.filter { $0.roomType == .common }
    }
}
