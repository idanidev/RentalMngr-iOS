import Testing
import Foundation
@testable import RentalMngr

@Suite("Tenant")
struct TenantTests {

    // MARK: - Room assignment

    @Test("isAssignedToRoom is true when room is set")
    func isAssignedToRoomTrue() {
        let tenant = makeTenant(room: makeTenantRoom())
        #expect(tenant.isAssignedToRoom == true)
    }

    @Test("isAssignedToRoom is false when room is nil")
    func isAssignedToRoomFalse() {
        let tenant = makeTenant(room: nil)
        #expect(tenant.isAssignedToRoom == false)
    }

    // MARK: - Effective monthly rent

    @Test("effectiveMonthlyRent uses room rent when room is assigned")
    func effectiveRentFromRoom() {
        let room = makeTenantRoom(rent: 650)
        let tenant = makeTenant(room: room, tenantRent: 400)
        #expect(tenant.effectiveMonthlyRent == 650)
    }

    @Test("effectiveMonthlyRent falls back to tenant rent when no room")
    func effectiveRentFromTenant() {
        let tenant = makeTenant(room: nil, tenantRent: 400)
        #expect(tenant.effectiveMonthlyRent == 400)
    }

    @Test("effectiveMonthlyRent is nil when neither room nor tenant rent is set")
    func effectiveRentNil() {
        let tenant = makeTenant(room: nil, tenantRent: nil)
        #expect(tenant.effectiveMonthlyRent == nil)
    }

    // MARK: - Contract status

    @Test("contractStatus is terminated when tenant is inactive")
    func contractStatusTerminated() {
        let tenant = makeTenant(active: false)
        #expect(tenant.contractStatus == .terminated)
    }

    @Test("contractStatus is noContract when active but no end date")
    func contractStatusNoContract() {
        let tenant = makeTenant(active: true, contractEndDate: nil)
        #expect(tenant.contractStatus == .noContract)
    }

    @Test("contractStatus is expired when end date is in the past")
    func contractStatusExpired() {
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tenant = makeTenant(active: true, contractEndDate: past)
        #expect(tenant.contractStatus == .expired)
    }

    @Test("contractStatus is expiringSoon when end date is within 30 days")
    func contractStatusExpiringSoon() {
        let soon = Calendar.current.date(byAdding: .day, value: 15, to: Date())!
        let tenant = makeTenant(active: true, contractEndDate: soon)
        #expect(tenant.contractStatus == .expiringSoon)
    }

    @Test("contractStatus is expiringSoon when end date is today")
    func contractStatusExpiringSoonToday() {
        let today = Date()
        let tenant = makeTenant(active: true, contractEndDate: today)
        #expect(tenant.contractStatus == .expiringSoon)
    }

    @Test("contractStatus is active when end date is more than 30 days away")
    func contractStatusActive() {
        let future = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        let tenant = makeTenant(active: true, contractEndDate: future)
        #expect(tenant.contractStatus == .active)
    }

    @Test("terminated status takes priority over expired contract")
    func terminatedBeforeExpired() {
        let past = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let tenant = makeTenant(active: false, contractEndDate: past)
        #expect(tenant.contractStatus == .terminated)
    }
}

// MARK: - Helpers

private func makeTenant(
    active: Bool = true,
    contractEndDate: Date? = nil,
    room: TenantRoom? = nil,
    tenantRent: Decimal? = nil
) -> Tenant {
    Tenant(
        id: UUID(),
        propertyId: UUID(),
        fullName: "Ana García",
        contractEndDate: contractEndDate,
        monthlyRent: tenantRent,
        active: active,
        room: room
    )
}

private func makeTenantRoom(rent: Decimal = 500) -> TenantRoom {
    TenantRoom(
        id: UUID(),
        name: "Habitación 1",
        monthlyRent: rent,
        sizeSqm: nil,
        roomType: .privateRoom
    )
}
