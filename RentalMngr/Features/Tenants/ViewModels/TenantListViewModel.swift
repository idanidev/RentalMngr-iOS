import Foundation
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "TenantListVM")

@MainActor @Observable
final class TenantListViewModel {
    var tenants: [Tenant] = []
    var showInactive: Bool
    var isLoading: Bool
    private(set) var isLoaded = false
    var errorMessage: String?
    let propertyId: UUID

    // Pagination
    var isLoadingMore = false
    var hasMoreData = true
    private var offset = 0
    private let limit = 20

    private let tenantService: TenantServiceProtocol
    private let roomService: RoomServiceProtocol
    private let realtimeService: RealtimeServiceProtocol
    @ObservationIgnored
    nonisolated(unsafe) private var realtimeTask: Task<Void, Never>?

    init(
        propertyId: UUID, tenantService: TenantServiceProtocol,
        roomService: RoomServiceProtocol,
        realtimeService: RealtimeServiceProtocol
    ) {
        self.propertyId = propertyId
        self.tenantService = tenantService
        self.roomService = roomService
        self.realtimeService = realtimeService
        self.showInactive = false
        self.isLoading = false
    }

    nonisolated deinit {
        realtimeTask?.cancel()
    }

    var filteredTenants: [Tenant] {
        showInactive ? tenants : tenants.filter(\.active)
    }

    func loadTenants() async {
        guard !isLoaded else { return }
        isLoading = true
        errorMessage = nil
        offset = 0
        hasMoreData = true

        do {
            logger.debug("Loading tenants for propertyId: \(self.propertyId)")

            // Start listening only once — structured concurrency via withTaskGroup
            if realtimeTask == nil {
                realtimeTask = Task { [weak self] in
                    guard let self else { return }
                    await self.listenForChanges()
                }
            }

            let newTenants = try await tenantService.fetchTenants(
                propertyId: propertyId, limit: limit, offset: 0
            )
            tenants = newTenants
            offset = newTenants.count
            hasMoreData = newTenants.count == limit

            logger.info(
                "Loaded \(self.tenants.count) tenants, active: \(self.tenants.filter(\.active).count)"
            )
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isLoading = false
            return
        } catch {
            logger.error("ERROR loading tenants: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoaded = true
        isLoading = false
    }

    func refresh() async {
        isLoaded = false
        await loadTenants()
    }

    func loadMore() async {
        guard !isLoadingMore, hasMoreData else { return }
        isLoadingMore = true

        do {
            let newTenants = try await tenantService.fetchTenants(
                propertyId: propertyId, limit: limit, offset: offset
            )
            tenants.append(contentsOf: newTenants)
            offset += newTenants.count
            hasMoreData = newTenants.count == limit
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isLoadingMore = false
            return
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    func deactivateTenant(_ tenant: Tenant) async {
        do {
            try await tenantService.deactivateTenant(id: tenant.id)
            await refreshData()
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reactivateTenant(_ tenant: Tenant) async {
        do {
            try await tenantService.activateTenant(id: tenant.id)
            await refreshData()
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkIn(tenantId: UUID, roomId: UUID) async {
        do {
            try await tenantService.assignToRoom(tenantId: tenantId, roomId: roomId)
            await refreshData()
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkOut(roomId: UUID) async {
        do {
            try await tenantService.unassignFromRoom(roomId: roomId)
            await refreshData()
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renewContract(tenant: Tenant, months: Int) async {
        do {
            try await tenantService.renewContract(tenantId: tenant.id, contractMonths: months, currentEndDate: tenant.contractEndDate)
            await refreshData()
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func listenForChanges() async {
        let service = realtimeService
        let tenantsStream = service.listenForChanges(table: SupabaseTable.tenants)
        let roomsStream = service.listenForChanges(table: SupabaseTable.rooms)

        // Structured concurrency — both cancel when the parent Task cancels
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in tenantsStream {
                    await self.refreshData()
                }
            }
            group.addTask {
                for await _ in roomsStream {
                    await self.refreshData()
                }
            }
        }
    }

    private func refreshData() async {
        do {
            let currentCount = max(limit, tenants.count)
            let allTenants = try await tenantService.fetchTenants(
                propertyId: propertyId, limit: currentCount, offset: 0
            )
            self.tenants = allTenants
            self.offset = allTenants.count
            // hasMoreData only if we got a full page — fewer means we've reached the end
            self.hasMoreData = (allTenants.count == currentCount)
        } catch {
            logger.error("Error refreshing tenants: \(error)")
        }
    }
}
