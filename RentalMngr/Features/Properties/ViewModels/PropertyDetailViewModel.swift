import Foundation

enum PropertyTab: String, CaseIterable {
    case rooms, tenants, finances, documents, contract

    var displayName: String {
        switch self {
        case .rooms: String(localized: "Rooms", locale: LanguageService.currentLocale, comment: "Property tab")
        case .tenants: String(localized: "Tenants", locale: LanguageService.currentLocale, comment: "Property tab")
        case .finances: String(localized: "Finances", locale: LanguageService.currentLocale, comment: "Property tab")
        case .documents: String(localized: "Documents", locale: LanguageService.currentLocale, comment: "Property tab")
        case .contract: String(localized: "Contract", locale: LanguageService.currentLocale, comment: "Property tab for contract template")
        }
    }

    var icon: String {
        switch self {
        case .rooms: "bed.double.fill"
        case .tenants: "person.2.fill"
        case .finances: "eurosign.circle.fill"
        case .documents: "doc.fill"
        case .contract: "doc.text.fill"
        }
    }
}

@MainActor @Observable
final class PropertyDetailViewModel {
    var property: Property
    var selectedTab: PropertyTab = .rooms
    var rooms: [Room] = []
    var tenants: [Tenant] = []
    var currentUserRole: AccessRole = .viewer
    var isLoading = false
    var errorMessage: String?

    var canEdit: Bool { currentUserRole != .viewer }

    private let propertyService: PropertyServiceProtocol
    private let roomService: RoomServiceProtocol
    private let tenantService: TenantServiceProtocol
    private let realtimeService: RealtimeServiceProtocol
    private let currentUserId: UUID?

    @ObservationIgnored
    nonisolated(unsafe) private var realtimeTask: Task<Void, Never>?
    @ObservationIgnored
    nonisolated(unsafe) private var refreshDebounceTask: Task<Void, Never>?

    init(
        property: Property,
        currentUserId: UUID?,
        propertyService: PropertyServiceProtocol,
        roomService: RoomServiceProtocol,
        tenantService: TenantServiceProtocol,
        realtimeService: RealtimeServiceProtocol
    ) {
        self.property = property
        self.currentUserId = currentUserId
        self.propertyService = propertyService
        self.roomService = roomService
        self.tenantService = tenantService
        self.realtimeService = realtimeService
    }

    nonisolated deinit {
        realtimeTask?.cancel()
        refreshDebounceTask?.cancel()
    }

    // MARK: - Public

    func loadData() async {
        isLoading = true
        errorMessage = nil

        if realtimeTask == nil {
            realtimeTask = Task { [weak self] in
                guard let self else { return }
                await self.listenForChanges()
            }
        }

        do {
            try await fetchAndMap(refreshProperty: false)
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isLoading = false
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshData() async {
        isLoading = true
        do {
            try await fetchAndMap(refreshProperty: true)
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isLoading = false
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Private

    /// Single source of truth for fetching rooms + tenants + members.
    /// Optionally re-fetches property metadata (name, address, description).
    private func fetchAndMap(refreshProperty: Bool) async throws {
        async let fetchedRoomsTask = roomService.fetchRooms(propertyId: property.id)
        async let fetchedTenantsTask = tenantService.fetchTenants(
            propertyId: property.id, limit: nil, offset: nil)
        async let membersTask = propertyService.getPropertyMembers(propertyId: property.id)

        var fetchedRooms = try await fetchedRoomsTask
        let fetchedTenants = try await fetchedTenantsTask
        let members = (try? await membersTask) ?? []

        if refreshProperty,
            let refreshed = try? await propertyService.fetchProperty(id: property.id)
        {
            property.name = refreshed.name
            property.address = refreshed.address
            property.description = refreshed.description
        }

        // Map active tenants onto their rooms
        for i in fetchedRooms.indices {
            if let tenant = fetchedTenants.first(where: {
                $0.room?.id == fetchedRooms[i].id && $0.active
            }) {
                fetchedRooms[i].tenantName = tenant.fullName
                fetchedRooms[i].tenantId = tenant.id
                fetchedRooms[i].occupied = true
            } else {
                fetchedRooms[i].tenantName = nil
                fetchedRooms[i].tenantId = nil
                fetchedRooms[i].occupied = false
            }
        }

        rooms = fetchedRooms
        property.rooms = rooms
        tenants = fetchedTenants
        currentUserRole = members.first(where: { $0.userId == currentUserId })?.role ?? .viewer
    }

    /// Debounces realtime-triggered refreshes to avoid a request storm when
    /// multiple tables fire simultaneously (e.g. rooms + tenants on tenant move).
    private nonisolated func scheduleRefresh() {
        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            await self.refreshData()
        }
    }

    private func listenForChanges() async {
        let service = realtimeService
        let propertiesStream = service.listenForChanges(table: SupabaseTable.properties)
        let roomsStream = service.listenForChanges(table: SupabaseTable.rooms)
        let tenantsStream = service.listenForChanges(table: SupabaseTable.tenants)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in propertiesStream { self.scheduleRefresh() }
            }
            group.addTask {
                for await _ in roomsStream { self.scheduleRefresh() }
            }
            group.addTask {
                for await _ in tenantsStream { self.scheduleRefresh() }
            }
        }
    }

    // MARK: - Computed

    var privateRooms: [Room] { property.privateRooms }
    var commonRooms: [Room] { property.commonRooms }
    var vacantCount: Int { property.vacantPrivateRooms.count }
    var activeTenants: [Tenant] { tenants.filter(\.active) }

    var occupiedRooms: Int { property.occupiedPrivateRooms.count }

    var occupancyRate: Double {
        let allPrivate = property.privateRooms  // single evaluation
        guard !allPrivate.isEmpty else { return 0 }
        return Double(property.occupiedPrivateRooms.count) / Double(allPrivate.count)
    }
}
