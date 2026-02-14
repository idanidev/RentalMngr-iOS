import Foundation

@Observable
final class PropertyListViewModel {
    var properties: [Property] = []
    var isLoading = false
    var errorMessage: String?
    var showAddProperty = false

    private let propertyService: PropertyService

    init(propertyService: PropertyService) {
        self.propertyService = propertyService
    }

    func loadProperties() async {
        isLoading = true
        errorMessage = nil
        do {
            properties = try await propertyService.fetchProperties()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
