import Foundation

enum HouseRuleCategory: String, Codable, Sendable, CaseIterable {
    case cleaning = "limpieza"
    case noise = "ruido"
    case visitors = "visitas"
    case kitchen = "cocina"
    case bathroom = "baño"
    case community = "comunidad"
    case other = "otro"

    var displayName: String {
        switch self {
        case .cleaning: String(localized: "Cleaning", locale: LanguageService.currentLocale, comment: "House rule category")
        case .noise: String(localized: "Noise", locale: LanguageService.currentLocale, comment: "House rule category")
        case .visitors: String(localized: "Visitors", locale: LanguageService.currentLocale, comment: "House rule category")
        case .kitchen: String(localized: "Kitchen", locale: LanguageService.currentLocale, comment: "House rule category")
        case .bathroom: String(localized: "Bathroom", locale: LanguageService.currentLocale, comment: "House rule category")
        case .community: String(localized: "Community", locale: LanguageService.currentLocale, comment: "House rule category")
        case .other: String(localized: "Other", locale: LanguageService.currentLocale, comment: "House rule category")
        }
    }
}

struct HouseRule: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var category: HouseRuleCategory
    var title: String
    var description: String?
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, category, title, description
        case propertyId = "property_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
