import Foundation

struct Property: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var description: String?
    let ownerId: UUID
    let createdAt: Date
    var updatedAt: Date?
    // Embedded rooms from join query: SELECT *, rooms(*)
    var rooms: [Room]?

    enum CodingKeys: String, CodingKey {
        case id, name, address, description, rooms
        case ownerId = "owner_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Computed: only private rooms
    var privateRooms: [Room] {
        (rooms ?? []).filter { $0.roomType == .privateRoom }
    }

    var commonRooms: [Room] {
        (rooms ?? []).filter { $0.roomType == .common }
    }

    var occupiedPrivateRooms: [Room] {
        privateRooms.filter(\.occupied)
    }

    var vacantPrivateRooms: [Room] {
        privateRooms.filter { !$0.occupied }
    }

    var occupancyRate: Double {
        guard !privateRooms.isEmpty else { return 0 }
        return Double(occupiedPrivateRooms.count) / Double(privateRooms.count) * 100
    }

    var monthlyRevenue: Decimal {
        occupiedPrivateRooms.reduce(Decimal.zero) { $0 + $1.monthlyRent }
    }
}
