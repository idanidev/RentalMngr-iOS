import SwiftUI

enum InventoryCondition: String, Codable, CaseIterable, Identifiable, Sendable {
    case new = "new"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case broken = "broken"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: return String(localized: "New", locale: LanguageService.currentLocale, comment: "Inventory condition new")
        case .good: return String(localized: "Good", locale: LanguageService.currentLocale, comment: "Inventory condition good")
        case .fair: return String(localized: "Fair", locale: LanguageService.currentLocale, comment: "Inventory condition fair")
        case .poor: return String(localized: "Poor", locale: LanguageService.currentLocale, comment: "Inventory condition poor")
        case .broken: return String(localized: "Broken", locale: LanguageService.currentLocale, comment: "Inventory condition broken")
        }
    }

    var color: Color {
        switch self {
        case .new: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .broken: return .gray
        }
    }
}

struct InventoryItem: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let roomId: UUID
    var name: String
    var description: String?
    var condition: InventoryCondition
    var purchaseDate: Date?
    var purchasePrice: Decimal?
    var photos: [String]?
    let createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case name
        case description
        case condition
        case purchaseDate = "purchase_date"
        case purchasePrice = "purchase_price"
        case photos
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

}
