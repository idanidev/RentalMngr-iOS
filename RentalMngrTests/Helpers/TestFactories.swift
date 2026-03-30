import Foundation
@testable import RentalMngr

// MARK: - Property

func makeProperty(
    id: UUID = UUID(),
    name: String = "Test Property",
    rooms: [Room]? = nil
) -> Property {
    Property(
        id: id,
        name: name,
        address: "Calle Mayor 1",
        description: nil,
        ownerId: UUID(),
        createdAt: Date(),
        updatedAt: nil,
        contractTemplate: nil,
        rooms: rooms
    )
}

// MARK: - Room

func makeRoom(
    id: UUID = UUID(),
    propertyId: UUID = UUID(),
    type: RoomType = .privateRoom,
    occupied: Bool = false,
    rent: Decimal = 500
) -> Room {
    Room(
        id: id,
        propertyId: propertyId,
        tenantId: nil,
        name: "Room",
        monthlyRent: rent,
        sizeSqm: nil,
        occupied: occupied,
        tenantName: nil,
        notes: nil,
        roomType: type,
        photos: [],
        createdAt: nil,
        updatedAt: nil
    )
}

// MARK: - Tenant

func makeTenant(
    id: UUID = UUID(),
    propertyId: UUID = UUID(),
    fullName: String = "Ana García",
    active: Bool = true,
    contractEndDate: Date? = nil,
    monthlyRent: Decimal? = nil,
    room: TenantRoom? = nil
) -> Tenant {
    Tenant(
        id: id,
        propertyId: propertyId,
        fullName: fullName,
        contractEndDate: contractEndDate,
        monthlyRent: monthlyRent,
        active: active,
        room: room
    )
}

// MARK: - Income
// Income only has init(from:) so we decode from JSON

func makeIncome(
    id: UUID = UUID(),
    propertyId: UUID = UUID(),
    roomId: UUID = UUID(),
    amount: Decimal = 500,
    paid: Bool = false
) -> Income {
    let json = """
    {
        "id": "\(id.uuidString)",
        "property_id": "\(propertyId.uuidString)",
        "room_id": "\(roomId.uuidString)",
        "amount": \(amount),
        "month": "2026-03-01",
        "paid": \(paid)
    }
    """
    let decoder = JSONDecoder()
    return try! decoder.decode(Income.self, from: Data(json.utf8))
}
