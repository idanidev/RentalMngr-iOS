import Foundation

/// Room info embedded in tenant from join: room:rooms!rooms_tenant_id_fkey(id, name, monthly_rent, size_sqm, room_type)
struct TenantRoom: Codable, Sendable, Hashable {
    let id: UUID
    let name: String
    let monthlyRent: Decimal
    let sizeSqm: Decimal?
    let roomType: RoomType

    enum CodingKeys: String, CodingKey {
        case id, name
        case monthlyRent = "monthly_rent"
        case sizeSqm = "size_sqm"
        case roomType = "room_type"
    }
}

struct Tenant: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var fullName: String
    var email: String?
    var phone: String?
    var dni: String?
    var contractStartDate: Date?
    var contractMonths: Int?
    var contractEndDate: Date?
    var depositAmount: Decimal?
    var monthlyRent: Decimal?
    var currentAddress: String?
    var notes: String?
    var contractNotes: String?
    var active: Bool
    let createdAt: Date?
    var updatedAt: Date?
    // Embedded room from join query
    var room: TenantRoom?

    init(
        id: UUID, propertyId: UUID, fullName: String, email: String? = nil, phone: String? = nil,
        dni: String? = nil, contractStartDate: Date? = nil, contractMonths: Int? = nil,
        contractEndDate: Date? = nil, depositAmount: Decimal? = nil, monthlyRent: Decimal? = nil,
        currentAddress: String? = nil, notes: String? = nil, contractNotes: String? = nil,
        active: Bool, createdAt: Date? = nil, updatedAt: Date? = nil, room: TenantRoom? = nil
    ) {
        self.id = id
        self.propertyId = propertyId
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.dni = dni
        self.contractStartDate = contractStartDate
        self.contractMonths = contractMonths
        self.contractEndDate = contractEndDate
        self.depositAmount = depositAmount
        self.monthlyRent = monthlyRent
        self.currentAddress = currentAddress
        self.notes = notes
        self.contractNotes = contractNotes
        self.active = active
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.room = room
    }

    enum CodingKeys: String, CodingKey {
        case id, email, phone, dni, active, notes, room
        case propertyId = "property_id"
        case fullName = "full_name"
        case contractStartDate = "contract_start_date"
        case contractMonths = "contract_months"
        case contractEndDate = "contract_end_date"
        case depositAmount = "deposit_amount"
        case monthlyRent = "monthly_rent"
        case currentAddress = "current_address"
        case contractNotes = "contract_notes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        propertyId = try container.decode(UUID.self, forKey: .propertyId)
        fullName = try container.decode(String.self, forKey: .fullName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        dni = try container.decodeIfPresent(String.self, forKey: .dni)
        contractStartDate = try container.decodeIfPresent(Date.self, forKey: .contractStartDate)
        contractMonths = try container.decodeIfPresent(Int.self, forKey: .contractMonths)
        contractEndDate = try container.decodeIfPresent(Date.self, forKey: .contractEndDate)
        depositAmount = try container.decodeIfPresent(Decimal.self, forKey: .depositAmount)
        monthlyRent = try container.decodeIfPresent(Decimal.self, forKey: .monthlyRent)
        currentAddress = try container.decodeIfPresent(String.self, forKey: .currentAddress)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        contractNotes = try container.decodeIfPresent(String.self, forKey: .contractNotes)
        active = try container.decode(Bool.self, forKey: .active)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        // Supabase returns room as array from join; take first element
        if let rooms = try? container.decode([TenantRoom].self, forKey: .room) {
            room = rooms.first
        } else {
            room = try? container.decode(TenantRoom.self, forKey: .room)
        }
    }

    /// Is this tenant assigned to a room?
    var isAssignedToRoom: Bool {
        room != nil
    }

    /// Effective monthly rent: from room if assigned, otherwise from tenant field
    var effectiveMonthlyRent: Decimal? {
        room?.monthlyRent ?? monthlyRent
    }

    /// Contract status
    var contractStatus: ContractStatus {
        guard let endDate = contractEndDate else { return .noContract }
        if endDate.isExpired { return .expired }
        if endDate.isExpiringSoon { return .expiringSoon }
        return .active
    }
}

enum ContractStatus {
    case active, expiringSoon, expired, noContract

    var label: String {
        switch self {
        case .active: "Activo"
        case .expiringSoon: "Por vencer"
        case .expired: "Expirado"
        case .noContract: "Sin contrato"
        }
    }
}
