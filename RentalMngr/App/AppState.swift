import Foundation
import SwiftUI

@Observable
final class AppState {
    var selectedProperty: Property?
    var searchText: String = ""
    var isShowingSearch: Bool = false

    let authService = AuthService()
    let propertyService = PropertyService()
    let roomService = RoomService()
    let tenantService = TenantService()
    let financeService = FinanceService()
    let notificationService = NotificationAppService()
    let storageService = StorageService()
    let searchService = SearchService()
    let houseRuleService = HouseRuleService()
    let sharedExpenseService = SharedExpenseService()
    let reminderService = ReminderService()
    let systemNotificationService = SystemNotificationService.shared
}

enum AppTab: Int, Hashable, CaseIterable {
    case dashboard = 0
    case properties = 1
    case finances = 2
    case notifications = 3
    case more = 4

    var title: String {
        switch self {
        case .dashboard: "Inicio"
        case .properties: "Propiedades"
        case .finances: "Finanzas"
        case .notifications: "Avisos"
        case .more: "Más"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "house.fill"
        case .properties: "building.2.fill"
        case .finances: "eurosign.circle.fill"
        case .notifications: "bell.fill"
        case .more: "ellipsis"
        }
    }
}
