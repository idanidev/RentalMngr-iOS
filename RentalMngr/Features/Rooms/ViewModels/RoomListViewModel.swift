import Foundation

@Observable
final class RoomListViewModel {
    var rooms: [Room] = []
    var isLoading = false
    var errorMessage: String?
    let propertyId: UUID

    private let roomService: RoomService

    init(propertyId: UUID, roomService: RoomService, rooms: [Room] = []) {
        self.propertyId = propertyId
        self.roomService = roomService
        self.rooms = rooms
    }

    func loadRooms() async {
        isLoading = true
        do {
            rooms = try await roomService.fetchRooms(propertyId: propertyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteRoom(_ room: Room) async {
        do {
            try await roomService.deleteRoom(id: room.id)
            rooms.removeAll { $0.id == room.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleOccupancy(_ room: Room) async {
        do {
            try await roomService.toggleOccupancy(roomId: room.id, occupied: !room.occupied)
            await loadRooms()
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
