import Foundation
import Supabase

final class RoomService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func fetchRooms(propertyId: UUID) async throws -> [Room] {
        try await client
            .from("rooms")
            .select()
            .eq("property_id", value: propertyId)
            .order("name")
            .execute()
            .value
    }

    func fetchRoom(id: UUID) async throws -> Room {
        try await client
            .from("rooms")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createRoom(propertyId: UUID, name: String, monthlyRent: Decimal, roomType: RoomType, sizeSqm: Decimal?) async throws -> Room {
        struct NewRoom: Encodable {
            let property_id: UUID
            let name: String
            let monthly_rent: Decimal
            let room_type: String
            let size_sqm: Decimal?
            let photos: [String]
        }
        return try await client
            .from("rooms")
            .insert(NewRoom(property_id: propertyId, name: name, monthly_rent: monthlyRent, room_type: roomType.rawValue, size_sqm: sizeSqm, photos: []))
            .select()
            .single()
            .execute()
            .value
    }

    func updateRoom(_ room: Room) async throws -> Room {
        struct UpdateRoom: Encodable {
            let name: String
            let monthly_rent: Decimal
            let room_type: String
            let size_sqm: Decimal?
            let notes: String?
            let photos: [String]
        }
        return try await client
            .from("rooms")
            .update(UpdateRoom(name: room.name, monthly_rent: room.monthlyRent, room_type: room.roomType.rawValue, size_sqm: room.sizeSqm, notes: room.notes, photos: room.photos))
            .eq("id", value: room.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteRoom(id: UUID) async throws {
        try await client
            .from("rooms")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func toggleOccupancy(roomId: UUID, occupied: Bool) async throws {
        struct OccupancyUpdate: Encodable {
            let occupied: Bool
        }
        try await client
            .from("rooms")
            .update(OccupancyUpdate(occupied: occupied))
            .eq("id", value: roomId)
            .execute()
    }
}
