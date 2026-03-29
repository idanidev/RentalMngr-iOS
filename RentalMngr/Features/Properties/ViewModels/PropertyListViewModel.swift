import Foundation
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "PropertyListVM")

@MainActor @Observable
final class PropertyListViewModel {
    var properties: [Property] = []
    var isLoading = false
    private(set) var isLoaded = false
    var errorMessage: String?
    var showAddProperty = false

    private let propertyService: PropertyServiceProtocol
    private let realtimeService: RealtimeServiceProtocol
    @ObservationIgnored
    nonisolated(unsafe) private var realtimeTask: Task<Void, Never>?

    init(
        propertyService: PropertyServiceProtocol,
        realtimeService: RealtimeServiceProtocol
    ) {
        self.propertyService = propertyService
        self.realtimeService = realtimeService
    }

    nonisolated deinit {
        realtimeTask?.cancel()
    }

    func loadProperties() async {
        guard !isLoaded else { return }
        isLoading = true
        errorMessage = nil

        // Start listening only once — avoids accumulating zombie Tasks
        if realtimeTask == nil {
            realtimeTask = Task { [weak self] in
                guard let self else { return }
                await self.listenForChanges()
            }
        }

        do {
            properties = try await propertyService.fetchProperties()
        } catch is CancellationError {
            // La tarea fue cancelada por navegación — no es un error real.
            // isLoaded queda false para que el próximo .task reintente.
            isLoading = false
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoaded = true
        isLoading = false
    }

    func refresh() async {
        isLoaded = false
        await loadProperties()
    }

    private func listenForChanges() async {
        for await _ in realtimeService.listenForChanges(table: SupabaseTable.properties) {
            do {
                properties = try await propertyService.fetchProperties()
            } catch {
                logger.error("Error refreshing properties from realtime: \(error)")
            }
        }
    }

    func deleteProperty(_ property: Property) async {
        do {
            try await propertyService.deleteProperty(id: property.id)
            properties.removeAll { $0.id == property.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
