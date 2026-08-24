import Foundation

struct Property: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var description: String?
    let ownerId: UUID
    let createdAt: Date
    var updatedAt: Date?
    var contractTemplate: String?
    /// `true` = la vivienda se alquila entera (cuenta como 1 unidad, aunque tenga
    /// varias habitaciones). `false` = alquiler por habitaciones.
    var isSingleUnit: Bool
    // Embedded rooms from join query: SELECT *, rooms(*)
    var rooms: [Room]?

    enum CodingKeys: String, CodingKey {
        case id, name, address, description, rooms
        case ownerId = "owner_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case contractTemplate = "contract_template"
        case isSingleUnit = "is_single_unit"
    }

    init(
        id: UUID, name: String, address: String, description: String? = nil,
        ownerId: UUID, createdAt: Date, updatedAt: Date? = nil,
        contractTemplate: String? = nil, isSingleUnit: Bool = false, rooms: [Room]? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.description = description
        self.ownerId = ownerId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.contractTemplate = contractTemplate
        self.isSingleUnit = isSingleUnit
        self.rooms = rooms
    }

    /// Tolerante con filas antiguas: la columna es nueva y puede no venir.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        address = try c.decode(String.self, forKey: .address)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        ownerId = try c.decode(UUID.self, forKey: .ownerId)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        contractTemplate = try c.decodeIfPresent(String.self, forKey: .contractTemplate)
        isSingleUnit = (try? c.decode(Bool.self, forKey: .isSingleUnit)) ?? false
        rooms = try c.decodeIfPresent([Room].self, forKey: .rooms)
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
