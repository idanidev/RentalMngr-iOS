import Foundation

// Service Protocols

protocol SystemNotificationServiceProtocol: Sendable {
    func requestPermission() async throws -> Bool
    func updatePaymentReminders(pendingCount: Int)
}

protocol PropertyServiceProtocol: Sendable {
    func fetchProperties() async throws -> [Property]
    func fetchProperty(id: UUID) async throws -> Property
    func createProperty(name: String, address: String, description: String?, ownerId: UUID)
        async throws -> Property
    func updateProperty(_ property: Property) async throws -> Property
    func updateContractTemplate(propertyId: UUID, template: String) async throws
    func deleteProperty(id: UUID) async throws
    // Invitations
    func inviteUser(propertyId: UUID, email: String, role: AccessRole, createdBy: UUID) async throws
        -> InviteResult
    func getPendingInvitations(propertyId: UUID) async throws -> [Invitation]
    func acceptInvitation(token: UUID, userId: UUID) async throws
    func processPendingInvitations(userId: UUID, email: String) async throws -> [String]
    func removeAccess(propertyId: UUID, userId: UUID) async throws
    func updateAccess(propertyId: UUID, userId: UUID, role: AccessRole) async throws
    // New methods
    func getMyInvitations(email: String) async throws -> [Invitation]
    func rejectInvitation(id: UUID) async throws
    func getPropertyAccess(propertyId: UUID) async throws -> [PropertyAccess]
    func getPropertyMembers(propertyId: UUID) async throws -> [PropertyMember]
    func revokeInvitation(id: UUID) async throws
}

protocol UserProfileServiceProtocol: Sendable {
    func getLandlordProfile() async throws -> LandlordProfile
    func saveLandlordProfile(_ profile: LandlordProfile) async throws
}

struct CreateTenantParams: Sendable {
    let propertyId: UUID
    let fullName: String
    let email: String?
    let phone: String?
    let dni: String?
    let contractStartDate: Date?
    let contractMonths: Int?
    let contractEndDate: Date?
    let depositAmount: Decimal?
    let monthlyRent: Decimal?
    let currentAddress: String?
    let notes: String?
    let contractNotes: String?
}

protocol TenantServiceProtocol: Sendable {
    func fetchTenants(propertyId: UUID, limit: Int?, offset: Int?) async throws -> [Tenant]
    func fetchActiveTenants(propertyId: UUID) async throws -> [Tenant]
    func fetchTenant(id: UUID) async throws -> Tenant
    func fetchAvailableTenants(propertyId: UUID) async throws -> [Tenant]
    func createTenant(_ params: CreateTenantParams) async throws -> Tenant
    func updateTenant(_ tenant: Tenant) async throws -> Tenant
    func deactivateTenant(id: UUID) async throws
    func activateTenant(id: UUID) async throws
    func assignToRoom(tenantId: UUID, roomId: UUID) async throws
    func unassignFromRoom(roomId: UUID) async throws
    func renewContract(tenantId: UUID, contractMonths: Int, currentEndDate: Date?) async throws
    func getExpiringContracts(daysAhead: Int) async throws -> [Tenant]
    func moveTenant(tenant: Tenant, toRoomId: UUID) async throws -> Tenant
}

protocol FinanceServiceProtocol: Sendable {
    func fetchIncome(
        propertyId: UUID, startDate: Date?, endDate: Date?, limit: Int?, offset: Int?
    ) async throws -> [Income]
    func fetchAllIncome(propertyIds: [UUID], startDate: Date, endDate: Date) async throws
        -> [Income]
    func createIncome(propertyId: UUID, roomId: UUID, amount: Decimal, month: Date) async throws
        -> Income
    func deleteIncome(id: UUID) async throws
    func fetchExpenses(
        propertyId: UUID, startDate: Date?, endDate: Date?, limit: Int?, offset: Int?
    ) async throws -> [Expense]
    func fetchExpensesByCategory(propertyId: UUID, startDate: Date?, endDate: Date?) async throws
        -> [(category: String, amount: Decimal)]
    func createExpense(
        propertyId: UUID, amount: Decimal, category: String, description: String?, date: Date,
        roomId: UUID?, createdBy: UUID
    ) async throws -> Expense
    func updateExpense(_ expense: Expense) async throws -> Expense
    func deleteExpense(id: UUID) async throws
    func getFinancialSummary(propertyId: UUID, year: Int?, month: Int?) async throws
        -> FinancialSummary
    func generateMonthlyIncome() async throws
    func markAsPaid(incomeId: UUID) async throws
    func markAsUnpaid(incomeId: UUID) async throws
}

protocol RoomServiceProtocol: Sendable {
    func fetchRooms(propertyId: UUID) async throws -> [Room]
    func fetchRoom(id: UUID) async throws -> Room
    func createRoom(
        propertyId: UUID, name: String, monthlyRent: Decimal, roomType: RoomType, sizeSqm: Decimal?
    ) async throws -> Room
    func updateRoom(_ room: Room) async throws -> Room
    func deleteRoom(id: UUID) async throws
    func toggleOccupancy(roomId: UUID, occupied: Bool) async throws
    func uploadPhoto(data: Data, path: String) async throws
}

protocol AuthServiceProtocol: Sendable {
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var currentUserEmail: String? { get }
    var currentUserId: UUID? { get }
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
    func resetPassword(email: String) async throws
    func observeAuthState() async
    /// Permanently deletes the account and all associated data via the delete_account RPC.
    func deleteAccount() async throws
}

protocol StorageServiceProtocol: Sendable {
    func uploadPhoto(propertyId: UUID, roomId: UUID, imageData: Data, index: Int) async throws
        -> String
    func getPublicURL(path: String) throws -> URL
    func deletePhoto(path: String) async throws
    func deletePhotos(paths: [String]) async throws

    // Generic methods
    func uploadFile(bucket: String, path: String, data: Data, contentType: String) async throws
        -> String
    func getPublicURL(bucket: String, path: String) throws -> URL
    func deleteFile(bucket: String, path: String) async throws
}

protocol NotificationServiceProtocol: Sendable {
    func fetchNotifications(userId: UUID, limit: Int, offset: Int, unreadOnly: Bool) async throws
        -> [AppNotification]
    func markAsRead(id: UUID) async throws
    func markAllAsRead(userId: UUID) async throws
    func deleteNotification(id: UUID) async throws
    func getUnreadCount(userId: UUID) async throws -> Int

    // Settings
    func fetchSettings(userId: UUID) async throws -> NotificationSettings?
    func fetchOrCreateSettings(userId: UUID) async throws -> NotificationSettings
    func updateSettings(_ settings: NotificationSettings) async throws

    // Local Notifications
    func requestLocalPermission() async throws -> Bool
    func scheduleContractExpiry(
        tenantName: String, expiryDate: Date, tenantId: UUID, alertDays: [Int]) async
    func scheduleRentReminders() async
    func scheduleWeeklyReport(weekday: Int) async
    func cancelWeeklyReport()
    func cancelContractExpiry(tenantId: UUID) async
}

protocol LocalAlertServiceProtocol: Sendable {
    func generateAlerts() async -> [LocalAlert]
}

protocol DocumentServiceProtocol: Sendable {
    func fetchDocuments(propertyId: UUID) async throws -> [Document]
    func fetchDocuments(tenantId: UUID) async throws -> [Document]
    func uploadDocument(
        data: Data, name: String, fileType: String, propertyId: UUID, tenantId: UUID?,
        uploadedBy: UUID
    ) async throws -> Document
    func deleteDocument(_ document: Document) async throws
    func getDocumentURL(_ document: Document) throws -> URL
}

protocol RealtimeServiceProtocol: Sendable {
    func listenForChanges(table: String) -> AsyncStream<RealtimeService.ChangeEvent>
}

protocol SearchServiceProtocol: Sendable {
    func search(query: String) async throws -> SearchResults
}

protocol HouseRuleServiceProtocol: Sendable {
    func fetchRules(propertyId: UUID) async throws -> [HouseRule]
    func createRule(
        propertyId: UUID, category: HouseRuleCategory, title: String,
        description: String?, createdBy: UUID
    ) async throws -> HouseRule
    func updateRule(_ rule: HouseRule) async throws -> HouseRule
    func deleteRule(id: UUID) async throws
}

protocol SharedExpenseServiceProtocol: Sendable {
    func fetchSharedExpenses(propertyId: UUID) async throws -> [SharedExpense]
    func createSharedExpense(
        propertyId: UUID, title: String, description: String?, amount: Decimal,
        category: SharedExpenseCategory, date: Date, splitType: SplitType,
        createdBy: UUID
    ) async throws -> SharedExpense
    func deleteSharedExpense(id: UUID) async throws
}

protocol ReminderServiceProtocol: Sendable {
    func fetchReminders(propertyId: UUID) async throws -> [Reminder]
    func fetchPendingReminders(propertyId: UUID) async throws -> [Reminder]
    func createReminder(
        propertyId: UUID, title: String, description: String?,
        reminderType: ReminderType, dueDate: Date, dueTime: String?,
        createdBy: UUID
    ) async throws -> Reminder
    func toggleCompleted(reminderId: UUID, completed: Bool) async throws
    func deleteReminder(id: UUID) async throws
}

protocol UtilityServiceProtocol: Sendable {
    func fetchPropertyUtilities(propertyId: UUID) async throws -> [PropertyUtility]
    func savePropertyUtilities(propertyId: UUID, utilities: [PropertyUtilityUpsert]) async throws
    func fetchUtilityCharges(
        propertyId: UUID, startDate: Date?, endDate: Date?, limit: Int?, offset: Int?
    ) async throws -> [UtilityCharge]
    func markUtilityPaid(chargeId: UUID) async throws
    func markUtilityUnpaid(chargeId: UUID) async throws
    func createUtilityCharge(
        propertyId: UUID, roomId: UUID, utilityType: String,
        amount: Decimal, month: Date
    ) async throws -> UtilityCharge
    func deleteUtilityCharge(id: UUID) async throws
    func fetchAllUtilityCharges(
        propertyIds: [UUID], startDate: Date, endDate: Date
    ) async throws -> [UtilityCharge]
    func generateMonthlyUtilityCharges(properties: [Property]) async throws
}

extension UtilityServiceProtocol {
    func fetchUtilityCharges(
        propertyId: UUID, startDate: Date? = nil, endDate: Date? = nil
    ) async throws -> [UtilityCharge] {
        try await fetchUtilityCharges(
            propertyId: propertyId, startDate: startDate, endDate: endDate,
            limit: nil, offset: nil
        )
    }
}

// MARK: - Default Implementations

extension TenantServiceProtocol {
    func fetchTenants(propertyId: UUID) async throws -> [Tenant] {
        try await fetchTenants(propertyId: propertyId, limit: nil, offset: nil)
    }
}

extension FinanceServiceProtocol {
    func fetchIncome(
        propertyId: UUID, startDate: Date? = nil, endDate: Date? = nil
    ) async throws -> [Income] {
        try await fetchIncome(
            propertyId: propertyId, startDate: startDate, endDate: endDate, limit: nil, offset: nil
        )
    }

    func fetchExpenses(
        propertyId: UUID, startDate: Date? = nil, endDate: Date? = nil
    ) async throws -> [Expense] {
        try await fetchExpenses(
            propertyId: propertyId, startDate: startDate, endDate: endDate, limit: nil, offset: nil
        )
    }
}
