import Testing
import Foundation
@testable import RentalMngr

@Suite("Property")
struct PropertyTests {

    // MARK: - Room filtering

    @Test("privateRooms only returns private-type rooms")
    func privateRoomsFilter() {
        let property = makeProperty(rooms: [
            makeRoom(type: .privateRoom),
            makeRoom(type: .common),
            makeRoom(type: .privateRoom),
        ])
        #expect(property.privateRooms.count == 2)
    }

    @Test("commonRooms only returns common-type rooms")
    func commonRoomsFilter() {
        let property = makeProperty(rooms: [
            makeRoom(type: .privateRoom),
            makeRoom(type: .common),
        ])
        #expect(property.commonRooms.count == 1)
    }

    @Test("privateRooms is empty when no rooms are set")
    func privateRoomsNilRooms() {
        let property = makeProperty(rooms: nil)
        #expect(property.privateRooms.isEmpty)
    }

    // MARK: - Occupancy

    @Test("occupiedPrivateRooms returns only occupied private rooms")
    func occupiedPrivateRooms() {
        let property = makeProperty(rooms: [
            makeRoom(type: .privateRoom, occupied: true),
            makeRoom(type: .privateRoom, occupied: false),
            makeRoom(type: .common, occupied: true), // common rooms should not count
        ])
        #expect(property.occupiedPrivateRooms.count == 1)
    }

    @Test("vacantPrivateRooms returns only unoccupied private rooms")
    func vacantPrivateRooms() {
        let property = makeProperty(rooms: [
            makeRoom(type: .privateRoom, occupied: true),
            makeRoom(type: .privateRoom, occupied: false),
            makeRoom(type: .privateRoom, occupied: false),
        ])
        #expect(property.vacantPrivateRooms.count == 2)
    }

    // MARK: - Occupancy rate

    @Test("occupancyRate is 0 when there are no private rooms")
    func occupancyRateNoRooms() {
        let property = makeProperty(rooms: [makeRoom(type: .common)])
        #expect(property.occupancyRate == 0)
    }

    @Test("occupancyRate is 0 when no rooms are set")
    func occupancyRateNilRooms() {
        let property = makeProperty(rooms: nil)
        #expect(property.occupancyRate == 0)
    }

    @Test("occupancyRate is 100 when all private rooms are occupied")
    func occupancyRateFullOccupancy() {
        let property = makeProperty(rooms: [
            makeRoom(type: .privateRoom, occupied: true),
            makeRoom(type: .privateRoom, occupied: true),
        ])
        #expect(property.occupancyRate == 100)
    }

    @Test("occupancyRate is 0 when no private rooms are occupied")
    func occupancyRateEmpty() {
        let property = makeProperty(rooms: [
            makeRoom(type: .privateRoom, occupied: false),
            makeRoom(type: .privateRoom, occupied: false),
        ])
        #expect(property.occupancyRate == 0)
    }

    @Test("occupancyRate computes correct percentage for partial occupancy")
    func occupancyRatePartial() {
        let property = makeProperty(rooms: [
            makeRoom(type: .privateRoom, occupied: true),
            makeRoom(type: .privateRoom, occupied: false),
            makeRoom(type: .privateRoom, occupied: false),
            makeRoom(type: .privateRoom, occupied: false),
        ])
        // 1 out of 4 = 25%
        #expect(property.occupancyRate == 25.0)
    }

    // MARK: - Monthly revenue

    @Test("monthlyRevenue sums rent from occupied private rooms only")
    func monthlyRevenueSumsOccupied() {
        let property = makeProperty(rooms: [
            makeRoom(type: .privateRoom, occupied: true, rent: 600),
            makeRoom(type: .privateRoom, occupied: true, rent: 400),
            makeRoom(type: .privateRoom, occupied: false, rent: 500), // vacant — not counted
            makeRoom(type: .common, occupied: true, rent: 100),       // common — not counted
        ])
        #expect(property.monthlyRevenue == 1000)
    }

    @Test("monthlyRevenue is zero when no rooms are occupied")
    func monthlyRevenueAllVacant() {
        let property = makeProperty(rooms: [
            makeRoom(type: .privateRoom, occupied: false, rent: 500),
        ])
        #expect(property.monthlyRevenue == 0)
    }

    @Test("monthlyRevenue is zero when rooms is nil")
    func monthlyRevenueNilRooms() {
        let property = makeProperty(rooms: nil)
        #expect(property.monthlyRevenue == 0)
    }
}

// MARK: - Helpers

private func makeProperty(rooms: [Room]? = nil) -> Property {
    Property(
        id: UUID(),
        name: "Test Property",
        address: "Calle Mayor 1",
        description: nil,
        ownerId: UUID(),
        createdAt: Date(),
        updatedAt: nil,
        contractTemplate: nil,
        rooms: rooms
    )
}

private func makeRoom(
    type: RoomType = .privateRoom,
    occupied: Bool = false,
    rent: Decimal = 500
) -> Room {
    Room(
        id: UUID(),
        propertyId: UUID(),
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
