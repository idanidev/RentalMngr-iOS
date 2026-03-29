import Foundation
import SwiftUI

@MainActor @Observable
final class AppState {
    var selectedProperty: Property?
    var propertiesNavigationPath = NavigationPath()
    var selectedTab: AppTab = .dashboard

    // Stored as concrete type so @Observable tracking works through AppState
    let authService: AuthService
    let propertyService: PropertyServiceProtocol
    let roomService: RoomServiceProtocol
    let tenantService: TenantServiceProtocol
    let financeService: FinanceServiceProtocol
    let notificationService: NotificationServiceProtocol
    let storageService: StorageServiceProtocol
    let searchService: SearchServiceProtocol
    let houseRuleService: HouseRuleServiceProtocol
    let sharedExpenseService: SharedExpenseServiceProtocol
    let reminderService: ReminderServiceProtocol
    let systemNotificationService: SystemNotificationService?
    let realtimeService: RealtimeServiceProtocol
    let userProfileService: UserProfileServiceProtocol
    let documentService: DocumentServiceProtocol
    let inventoryService: InventoryServiceProtocol
    let utilityService: UtilityServiceProtocol
    let languageService = LanguageService()

    // Theme Persistence
    var userInterfaceStyle: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(userInterfaceStyle.rawValue, forKey: "userInterfaceStyle")
        }
    }

    init() {
        self.authService = AuthService()
        self.propertyService = PropertyService()
        self.roomService = RoomService()
        self.tenantService = TenantService()
        self.financeService = FinanceService()
        self.storageService = StorageService()
        self.notificationService = NotificationAppService()
        self.searchService = SearchService()
        self.houseRuleService = HouseRuleService()
        self.sharedExpenseService = SharedExpenseService()
        self.reminderService = ReminderService()
        self.realtimeService = RealtimeService()
        self.userProfileService = UserProfileService()
        self.documentService = DocumentService(storageService: self.storageService)
        self.inventoryService = InventoryService()
        self.utilityService = UtilityService()

        // Load Theme
        if let savedTheme = UserDefaults.standard.string(forKey: "userInterfaceStyle"),
            let theme = AppTheme(rawValue: savedTheme)
        {
            self.userInterfaceStyle = theme
        }

        #if os(macOS)
            self.systemNotificationService = nil
        #else
            self.systemNotificationService = SystemNotificationService.shared
        #endif
    }
}

enum AppTab: Int, Hashable, CaseIterable {
    case dashboard = 0
    case properties = 1
    case finances = 2

    var title: String {
        switch self {
        case .dashboard: String(localized: "Home", locale: LanguageService.currentLocale, comment: "Tab title")
        case .properties: String(localized: "Properties", locale: LanguageService.currentLocale, comment: "Tab title")
        case .finances: String(localized: "Finances", locale: LanguageService.currentLocale, comment: "Tab title")
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "house.fill"
        case .properties: "building.2.fill"
        case .finances: "chart.line.uptrend.xyaxis"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    // rawValues kept as Spanish for backward compat with existing UserDefaults
    case system = "Sistema"
    case light = "Claro"
    case dark = "Oscuro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: String(localized: "System", locale: LanguageService.currentLocale, comment: "Theme option")
        case .light: String(localized: "Light", locale: LanguageService.currentLocale, comment: "Theme option")
        case .dark: String(localized: "Dark", locale: LanguageService.currentLocale, comment: "Theme option")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var icon: String {
        switch self {
        case .system: "gear"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

@Observable
final class LanguageService {
    // Accessible from String(localized:locale:) calls throughout the app
    nonisolated(unsafe) static var currentLocale: Locale = .current

    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "selectedLanguage")
            LanguageService.currentLocale = selectedLanguage.locale
        }
    }

    init() {
        if let stored = UserDefaults.standard.string(forKey: "selectedLanguage"),
            let language = AppLanguage(rawValue: stored)
        {
            self.selectedLanguage = language
            LanguageService.currentLocale = language.locale
        } else {
            // Default to system language if supported, else English
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            let language = AppLanguage(rawValue: systemLang) ?? .english
            self.selectedLanguage = language
            LanguageService.currentLocale = language.locale
        }
    }
}
