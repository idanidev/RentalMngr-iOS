import Foundation

@Observable
final class PropertyFormViewModel {
    var name = ""
    var address = ""
    var description = ""
    var isLoading = false
    var errorMessage: String?

    let isEditing: Bool
    private var propertyId: UUID?
    private let propertyService: PropertyService
    private let userId: UUID

    init(propertyService: PropertyService, userId: UUID, property: Property? = nil) {
        self.propertyService = propertyService
        self.userId = userId
        if let property {
            self.isEditing = true
            self.propertyId = property.id
            self.name = property.name
            self.address = property.address
            self.description = property.description ?? ""
        } else {
            self.isEditing = false
        }
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func save() async -> Property? {
        isLoading = true
        errorMessage = nil
        do {
            if isEditing, let propertyId {
                var updated = Property(
                    id: propertyId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    address: address.trimmingCharacters(in: .whitespaces),
                    description: description.isEmpty ? nil : description,
                    ownerId: userId,
                    createdAt: Date()
                )
                let result = try await propertyService.updateProperty(updated)
                isLoading = false
                return result
            } else {
                let result = try await propertyService.createProperty(
                    name: name.trimmingCharacters(in: .whitespaces),
                    address: address.trimmingCharacters(in: .whitespaces),
                    description: description.isEmpty ? nil : description,
                    ownerId: userId
                )
                isLoading = false
                return result
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
