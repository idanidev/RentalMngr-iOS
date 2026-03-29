import Foundation

enum SharedExpenseCategory: String, Codable, Sendable, CaseIterable {
    case utilities = "servicios"
    case shopping = "compras"
    case repairs = "reparaciones"
    case cleaning = "limpieza"
    case other = "otro"

    var displayName: String {
        switch self {
        case .utilities: String(localized: "Utilities", locale: LanguageService.currentLocale, comment: "Shared expense category")
        case .shopping: String(localized: "Shopping", locale: LanguageService.currentLocale, comment: "Shared expense category")
        case .repairs: String(localized: "Repairs", locale: LanguageService.currentLocale, comment: "Shared expense category")
        case .cleaning: String(localized: "Cleaning", locale: LanguageService.currentLocale, comment: "Shared expense category")
        case .other: String(localized: "Other", locale: LanguageService.currentLocale, comment: "Shared expense category")
        }
    }
}

enum SplitType: String, Codable, Sendable, CaseIterable {
    case equal
    case custom
    case byRoom = "by_room"

    var displayName: String {
        switch self {
        case .equal: String(localized: "Equal Split", locale: LanguageService.currentLocale, comment: "Split type")
        case .custom: String(localized: "Custom", locale: LanguageService.currentLocale, comment: "Split type")
        case .byRoom: String(localized: "By Room", locale: LanguageService.currentLocale, comment: "Split type")
        }
    }
}

struct SharedExpense: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var title: String
    var description: String?
    var amount: Decimal
    var category: SharedExpenseCategory
    var date: Date
    var splitType: SplitType
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, amount, category, date
        case propertyId = "property_id"
        case splitType = "split_type"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
