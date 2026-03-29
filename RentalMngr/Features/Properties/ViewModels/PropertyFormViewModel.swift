import Foundation

/// Editable utility configuration for the property form
struct EditableUtility: Identifiable {
    let type: UtilityType
    var enabled: Bool

    var id: String { type.rawValue }
}

@MainActor @Observable
final class PropertyFormViewModel {
    var name = ""
    var address = ""
    var description = ""
    var utilities: [EditableUtility] = []
    var isLoading = false
    var errorMessage: String?

    let isEditing: Bool
    private var propertyId: UUID?
    private let propertyService: PropertyServiceProtocol
    private let utilityService: UtilityServiceProtocol
    private let userId: UUID

    init(
        propertyService: PropertyServiceProtocol,
        utilityService: UtilityServiceProtocol,
        userId: UUID,
        property: Property? = nil
    ) {
        self.propertyService = propertyService
        self.utilityService = utilityService
        self.userId = userId

        // Initialize all utility types as disabled
        self.utilities = UtilityType.allCases.map { type in
            EditableUtility(type: type, enabled: false)
        }

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

    /// Load existing utility configuration when editing a property
    func loadUtilities() async {
        guard let propertyId else { return }
        do {
            let existing = try await utilityService.fetchPropertyUtilities(propertyId: propertyId)
            for config in existing {
                if let index = utilities.firstIndex(where: { $0.type.rawValue == config.utilityType }) {
                    utilities[index].enabled = true
                }
            }
        } catch {
            // Non-critical: just log and continue
            errorMessage = error.localizedDescription
        }
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func save() async -> Property? {
        isLoading = true
        errorMessage = nil
        do {
            let result: Property
            if isEditing, let propertyId {
                let updated = Property(
                    id: propertyId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    address: address.trimmingCharacters(in: .whitespaces),
                    description: description.isEmpty ? nil : description,
                    ownerId: userId,
                    createdAt: Date()
                )
                result = try await propertyService.updateProperty(updated)
            } else {
                result = try await propertyService.createProperty(
                    name: name.trimmingCharacters(in: .whitespaces),
                    address: address.trimmingCharacters(in: .whitespaces),
                    description: description.isEmpty ? nil : description,
                    ownerId: userId
                )
            }

            // Save utility configuration (all enabled utilities are trackable, never "included in rent")
            let enabledUtilities = utilities
                .filter(\.enabled)
                .map { utility in
                    PropertyUtilityUpsert(
                        property_id: result.id,
                        utility_type: utility.type.rawValue,
                        included_in_rent: false,
                        monthly_amount: nil
                    )
                }
            try await utilityService.savePropertyUtilities(
                propertyId: result.id, utilities: enabledUtilities
            )

            isLoading = false
            return result
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
