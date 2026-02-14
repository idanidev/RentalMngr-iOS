import Foundation

// MARK: - Local Alert Types

enum LocalAlertType: String, CaseIterable {
    case contractExpiring = "contract_expiring"
    case contractExpired = "contract_expired"
    case unpaidRent = "unpaid_rent"
}

enum AlertSeverity: Comparable {
    case info
    case warning
    case critical
}

// MARK: - Local Alert Model

struct LocalAlert: Identifiable {
    let id: String
    let type: LocalAlertType
    let severity: AlertSeverity
    let title: String
    let message: String
    let propertyName: String
    let actionLabel: String?
    let relatedTenantId: UUID?
    let relatedPropertyId: UUID?
    let relatedIncomeId: UUID?
    let daysUntilExpiry: Int?  // For contract alerts

    var icon: String {
        switch type {
        case .contractExpiring: "doc.badge.clock"
        case .contractExpired: "doc.badge.ellipsis"
        case .unpaidRent: "eurosign.circle"
        }
    }

    var color: String {
        switch severity {
        case .info: "blue"
        case .warning: "orange"
        case .critical: "red"
        }
    }
}
