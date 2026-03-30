import Foundation
@testable import RentalMngr

// MARK: - Error

enum MockError: Error {
    case notStubbed
    case forced(String)
}

// MARK: - MockPropertyService

final class MockPropertyService: PropertyServiceProtocol, @unchecked Sendable {
    var stubbedProperties: [Property] = []
    var stubbedError: Error?
    var deleteCallCount = 0
    var lastDeletedId: UUID?

    func fetchProperties() async throws -> [Property] {
        if let error = stubbedError { throw error }
        return stubbedProperties
    }

    func fetchProperty(id: UUID) async throws -> Property {
        if let error = stubbedError { throw error }
        return try stubbedProperties.first { $0.id == id } ?? { throw MockError.notStubbed }()
    }

    func createProperty(name: String, address: String, description: String?, ownerId: UUID) async throws -> Property {
        throw MockError.notStubbed
    }

    func updateProperty(_ property: Property) async throws -> Property {
        if let error = stubbedError { throw error }
        return property
    }

    func updateContractTemplate(propertyId: UUID, template: String) async throws {}

    func deleteProperty(id: UUID) async throws {
        if let error = stubbedError { throw error }
        deleteCallCount += 1
        lastDeletedId = id
    }

    func inviteUser(propertyId: UUID, email: String, role: AccessRole, createdBy: UUID) async throws -> InviteResult {
        throw MockError.notStubbed
    }

    func getPendingInvitations(propertyId: UUID) async throws -> [Invitation] { [] }

    func acceptInvitation(token: UUID, userId: UUID) async throws {}

    func processPendingInvitations(userId: UUID, email: String) async throws -> [String] { [] }

    func removeAccess(propertyId: UUID, userId: UUID) async throws {}

    func updateAccess(propertyId: UUID, userId: UUID, role: AccessRole) async throws {}

    func getMyInvitations(email: String) async throws -> [Invitation] { [] }

    func rejectInvitation(id: UUID) async throws {}

    func getPropertyAccess(propertyId: UUID) async throws -> [PropertyAccess] { [] }

    func getPropertyMembers(propertyId: UUID) async throws -> [PropertyMember] { [] }

    func revokeInvitation(id: UUID) async throws {}
}

// MARK: - MockRoomService

final class MockRoomService: RoomServiceProtocol, @unchecked Sendable {
    var stubbedRooms: [Room] = []
    var stubbedError: Error?

    func fetchRooms(propertyId: UUID) async throws -> [Room] {
        if let error = stubbedError { throw error }
        return stubbedRooms
    }

    func fetchRoom(id: UUID) async throws -> Room {
        throw MockError.notStubbed
    }

    func createRoom(propertyId: UUID, name: String, monthlyRent: Decimal, roomType: RoomType, sizeSqm: Decimal?) async throws -> Room {
        throw MockError.notStubbed
    }

    func updateRoom(_ room: Room) async throws -> Room { room }

    func deleteRoom(id: UUID) async throws {}

    func toggleOccupancy(roomId: UUID, occupied: Bool) async throws {}

    func uploadPhoto(data: Data, path: String) async throws {}
}

// MARK: - MockTenantService

final class MockTenantService: TenantServiceProtocol, @unchecked Sendable {
    var stubbedTenants: [Tenant] = []
    var stubbedExpiringContracts: [Tenant] = []
    var stubbedError: Error?
    var deactivateCallCount = 0
    var activateCallCount = 0
    var renewCallCount = 0

    func fetchTenants(propertyId: UUID, limit: Int?, offset: Int?) async throws -> [Tenant] {
        if let error = stubbedError { throw error }
        let from = offset ?? 0
        let all = stubbedTenants
        guard from < all.count else { return [] }
        let slice = all[from...]
        if let limit {
            return Array(slice.prefix(limit))
        }
        return Array(slice)
    }

    func fetchActiveTenants(propertyId: UUID) async throws -> [Tenant] {
        if let error = stubbedError { throw error }
        return stubbedTenants.filter(\.active)
    }

    func fetchTenant(id: UUID) async throws -> Tenant {
        throw MockError.notStubbed
    }

    func fetchAvailableTenants(propertyId: UUID) async throws -> [Tenant] { [] }

    func createTenant(_ params: CreateTenantParams) async throws -> Tenant {
        throw MockError.notStubbed
    }

    func updateTenant(_ tenant: Tenant) async throws -> Tenant { tenant }

    func deactivateTenant(id: UUID) async throws {
        if let error = stubbedError { throw error }
        deactivateCallCount += 1
    }

    func activateTenant(id: UUID) async throws {
        if let error = stubbedError { throw error }
        activateCallCount += 1
    }

    func assignToRoom(tenantId: UUID, roomId: UUID) async throws {}

    func unassignFromRoom(roomId: UUID) async throws {}

    func renewContract(tenantId: UUID, contractMonths: Int, currentEndDate: Date?) async throws {
        if let error = stubbedError { throw error }
        renewCallCount += 1
    }

    func getExpiringContracts(daysAhead: Int) async throws -> [Tenant] {
        if let error = stubbedError { throw error }
        return stubbedExpiringContracts
    }

    func moveTenant(tenant: Tenant, toRoomId: UUID) async throws -> Tenant { tenant }
}

// MARK: - MockFinanceService

final class MockFinanceService: FinanceServiceProtocol, @unchecked Sendable {
    var stubbedIncome: [Income] = []
    var stubbedExpenses: [Expense] = []
    var stubbedError: Error?

    func fetchIncome(propertyId: UUID, startDate: Date?, endDate: Date?, limit: Int?, offset: Int?) async throws -> [Income] {
        if let error = stubbedError { throw error }
        return stubbedIncome
    }

    func fetchAllIncome(propertyIds: [UUID], startDate: Date, endDate: Date) async throws -> [Income] {
        if let error = stubbedError { throw error }
        return stubbedIncome
    }

    func createIncome(propertyId: UUID, roomId: UUID, amount: Decimal, month: Date) async throws -> Income {
        throw MockError.notStubbed
    }

    func deleteIncome(id: UUID) async throws {}

    func fetchExpenses(propertyId: UUID, startDate: Date?, endDate: Date?, limit: Int?, offset: Int?) async throws -> [Expense] {
        if let error = stubbedError { throw error }
        return stubbedExpenses
    }

    func fetchExpensesByCategory(propertyId: UUID, startDate: Date?, endDate: Date?) async throws -> [(category: String, amount: Decimal)] { [] }

    func createExpense(propertyId: UUID, amount: Decimal, category: String, description: String?, date: Date, roomId: UUID?, createdBy: UUID) async throws -> Expense {
        throw MockError.notStubbed
    }

    func updateExpense(_ expense: Expense) async throws -> Expense { expense }

    func deleteExpense(id: UUID) async throws {}

    func getFinancialSummary(propertyId: UUID, year: Int?, month: Int?) async throws -> FinancialSummary {
        FinancialSummary(totalIncome: 0, paidIncome: 0, pendingIncome: 0, totalExpenses: 0, paidCount: 0, unpaidCount: 0)
    }

    func generateMonthlyIncome() async throws {}

    func markAsPaid(incomeId: UUID) async throws {}

    func markAsUnpaid(incomeId: UUID) async throws {}
}

// MARK: - MockRealtimeService

final class MockRealtimeService: RealtimeServiceProtocol, @unchecked Sendable {
    /// Controls whether the stream emits a single event or stays empty.
    var emitEvent = false

    func listenForChanges(table: String) -> AsyncStream<RealtimeService.ChangeEvent> {
        let shouldEmit = emitEvent
        return AsyncStream { continuation in
            if shouldEmit {
                continuation.yield(.all)
            }
            continuation.finish()
        }
    }
}
