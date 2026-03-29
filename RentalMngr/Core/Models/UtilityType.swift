import Foundation
import SwiftUI

/// Types of utility services that a property can have configured.
enum UtilityType: String, Codable, CaseIterable, Sendable, Identifiable {
    case electricity
    case heating
    case gas
    case water
    case internet
    case trash
    case communityFees = "community_fees"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .electricity: String(localized: "Electricity", locale: LanguageService.currentLocale, comment: "Utility type")
        case .heating: String(localized: "Heating", locale: LanguageService.currentLocale, comment: "Utility type")
        case .gas: String(localized: "Gas", locale: LanguageService.currentLocale, comment: "Utility type")
        case .water: String(localized: "Water", locale: LanguageService.currentLocale, comment: "Utility type")
        case .internet: String(localized: "Internet", locale: LanguageService.currentLocale, comment: "Utility type")
        case .trash: String(localized: "Trash collection", locale: LanguageService.currentLocale, comment: "Utility type")
        case .communityFees: String(localized: "Community fees", locale: LanguageService.currentLocale, comment: "Utility type")
        }
    }

    var icon: String {
        switch self {
        case .electricity: "bolt.fill"
        case .heating: "flame.fill"
        case .gas: "fuelpump.fill"
        case .water: "drop.fill"
        case .internet: "wifi"
        case .trash: "trash.fill"
        case .communityFees: "building.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .electricity: .yellow
        case .heating: .orange
        case .gas: .red
        case .water: .blue
        case .internet: .purple
        case .trash: .gray
        case .communityFees: .teal
        }
    }
}
