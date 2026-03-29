import Foundation

/// Configuration of a utility service for a property.
/// Determines which utilities the property has and whether they are included in rent.
struct PropertyUtility: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var utilityType: String
    var includedInRent: Bool
    var monthlyAmount: Decimal?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case utilityType = "utility_type"
        case includedInRent = "included_in_rent"
        case monthlyAmount = "monthly_amount"
        case createdAt = "created_at"
    }

    /// Resolved UtilityType enum (nil if unknown type)
    var type: UtilityType? {
        UtilityType(rawValue: utilityType)
    }
}
