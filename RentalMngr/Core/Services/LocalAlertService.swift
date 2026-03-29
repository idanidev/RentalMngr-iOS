import Foundation
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "LocalAlertService")

/// Generates local alerts by scanning existing data — no server-side logic needed.
final class LocalAlertService: LocalAlertServiceProtocol {
    private let tenantService: TenantServiceProtocol
    private let financeService: FinanceServiceProtocol
    private let propertyService: PropertyServiceProtocol
    private let utilityService: UtilityServiceProtocol

    init(
        tenantService: TenantServiceProtocol,
        financeService: FinanceServiceProtocol,
        propertyService: PropertyServiceProtocol,
        utilityService: UtilityServiceProtocol
    ) {
        self.tenantService = tenantService
        self.financeService = financeService
        self.propertyService = propertyService
        self.utilityService = utilityService
    }

    /// Generate all local alerts across all properties.
    /// Scans the last 12 months so accumulated unpaid items keep showing.
    func generateAlerts() async -> [LocalAlert] {
        var alerts: [LocalAlert] = []

        do {
            let properties = try await propertyService.fetchProperties()
            guard !properties.isEmpty else { return [] }

            let now = Date()
            let calendar = Calendar.current

            // Look back 12 months to catch accumulated unpaid rent/utilities
            let startOfCurrentMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now))!
            let lookbackStart = calendar.date(
                byAdding: .month, value: -12, to: startOfCurrentMonth)!
            let endOfCurrentMonth = calendar.date(
                byAdding: DateComponents(month: 1, second: -1), to: startOfCurrentMonth)!

            let propertyIds = properties.map(\.id)

            // Fetch unpaid income AND utility charges in parallel (12-month window)
            async let fetchIncome = financeService.fetchAllIncome(
                propertyIds: propertyIds,
                startDate: lookbackStart,
                endDate: endOfCurrentMonth
            )
            // Utilities: only current month — amounts are €0 by default so past months are noise
            async let fetchUtilities = utilityService.fetchAllUtilityCharges(
                propertyIds: propertyIds,
                startDate: startOfCurrentMonth,
                endDate: endOfCurrentMonth
            )
            async let fetchTenants: [(UUID, String, [Tenant])] = withThrowingTaskGroup(
                of: (UUID, String, [Tenant]).self
            ) { group in
                for property in properties {
                    group.addTask {
                        let tenants = try await self.tenantService.fetchTenants(
                            propertyId: property.id)
                        return (property.id, property.name, tenants)
                    }
                }
                var results: [(UUID, String, [Tenant])] = []
                for try await result in group { results.append(result) }
                return results
            }

            let allIncome = try await fetchIncome
            let allUtilities = try await fetchUtilities
            let allTenants = try await fetchTenants

            // Property name lookup
            let propertyNames = Dictionary(
                uniqueKeysWithValues: properties.map { ($0.id, $0.name) })

            // Contract alerts
            for (propertyId, propertyName, tenants) in allTenants {
                alerts.append(
                    contentsOf: generateContractAlerts(
                        tenants: tenants, propertyName: propertyName, propertyId: propertyId))
            }

            // Unpaid rent alerts — all months, not just current
            let incomeByProperty = Dictionary(
                grouping: allIncome.filter { !$0.paid }, by: \.propertyId)
            for property in properties {
                let unpaid = incomeByProperty[property.id] ?? []
                alerts.append(
                    contentsOf: generateUnpaidRentAlerts(
                        income: unpaid,
                        propertyName: property.name,
                        propertyId: property.id,
                        now: now,
                        calendar: calendar
                    ))
            }

            // Unpaid utility charge alerts — all months, not just current
            let utilitiesByProperty = Dictionary(
                grouping: allUtilities.filter { !$0.paid }, by: \.propertyId)
            for property in properties {
                let unpaid = utilitiesByProperty[property.id] ?? []
                alerts.append(
                    contentsOf: generateUnpaidUtilityAlerts(
                        charges: unpaid,
                        propertyName: propertyNames[property.id] ?? property.name,
                        propertyId: property.id,
                        now: now,
                        calendar: calendar
                    ))
            }

        } catch {
            logger.error("Error generating alerts: \(error.localizedDescription)")
        }

        // Sort: critical first, then warning, then info; within same severity by month (oldest first)
        return alerts.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return true
        }
    }

    // MARK: - Contract Alerts

    private func generateContractAlerts(tenants: [Tenant], propertyName: String, propertyId: UUID)
        -> [LocalAlert]
    {
        let now = Date()
        let calendar = Calendar.current
        var alerts: [LocalAlert] = []

        for tenant in tenants where tenant.active {
            guard let endDate = tenant.contractEndDate else { continue }

            let days = calendar.dateComponents([.day], from: now, to: endDate).day ?? 0

            if days < 0 {
                alerts.append(
                    LocalAlert(
                        id: "contract_expired_\(tenant.id)",
                        type: .contractExpired,
                        severity: .critical,
                        title: String(
                            localized: "Contract expired", locale: LanguageService.currentLocale,
                            comment: "Alert title for expired contract"),
                        message: String(
                            localized:
                                "\(tenant.fullName) — contract expired \(abs(days)) days ago",
                            locale: LanguageService.currentLocale,
                            comment: "Alert message for expired contract"),
                        propertyName: propertyName,
                        actionLabel: String(
                            localized: "Renew", locale: LanguageService.currentLocale,
                            comment: "Alert action to renew contract"),
                        relatedTenantId: tenant.id,
                        relatedPropertyId: propertyId,
                        relatedIncomeId: nil,
                        relatedUtilityChargeId: nil,
                        daysUntilExpiry: days
                    ))
            } else if days <= 30 {
                let severity: AlertSeverity = days <= 7 ? .critical : .warning
                alerts.append(
                    LocalAlert(
                        id: "contract_expiring_\(tenant.id)",
                        type: .contractExpiring,
                        severity: severity,
                        title: days == 0
                            ? String(
                                localized: "Contract expires today",
                                locale: LanguageService.currentLocale,
                                comment: "Alert title for contract expiring today")
                            : String(
                                localized: "Contract expires in \(days) days",
                                locale: LanguageService.currentLocale,
                                comment: "Alert title for contract expiring soon"),
                        message: String(
                            localized: "\(tenant.fullName) in \(tenant.room?.name ?? "—")",
                            locale: LanguageService.currentLocale,
                            comment: "Alert message for expiring contract with tenant name and room"
                        ),
                        propertyName: propertyName,
                        actionLabel: String(
                            localized: "Renew", locale: LanguageService.currentLocale,
                            comment: "Alert action to renew contract"),
                        relatedTenantId: tenant.id,
                        relatedPropertyId: propertyId,
                        relatedIncomeId: nil,
                        relatedUtilityChargeId: nil,
                        daysUntilExpiry: days
                    ))
            }
        }
        return alerts
    }

    // MARK: - Unpaid Rent Alerts (accumulative — all months)

    private func generateUnpaidRentAlerts(
        income: [Income], propertyName: String, propertyId: UUID,
        now: Date, calendar: Calendar
    ) -> [LocalAlert] {
        let currentDay = calendar.component(.day, from: now)

        return income.map { entry in
            let monthsAgo = calendar.dateComponents([.month], from: entry.month, to: now).month ?? 0
            let severity: AlertSeverity
            switch monthsAgo {
            case 0: severity = currentDay > 5 ? .warning : .info
            case 1: severity = .warning
            default: severity = .critical  // 2+ months overdue
            }

            let monthLabel = entry.month.formatted(.dateTime.month(.wide).year())
            let roomName = entry.roomName
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "EUR"
            let amountStr =
                formatter.string(from: entry.amount as NSDecimalNumber) ?? "\(entry.amount)€"

            return LocalAlert(
                id: "unpaid_\(entry.id)",
                type: .unpaidRent,
                severity: severity,
                title: String(
                    localized: "Pending payment — \(roomName)",
                    locale: LanguageService.currentLocale,
                    comment: "Alert title for unpaid rent"),
                message: monthsAgo > 0 ? "\(amountStr) · \(monthLabel)" : amountStr,
                propertyName: propertyName,
                actionLabel: String(
                    localized: "Mark as paid", locale: LanguageService.currentLocale,
                    comment: "Alert action to mark rent as paid"),
                relatedTenantId: nil,
                relatedPropertyId: propertyId,
                relatedIncomeId: entry.id,
                relatedUtilityChargeId: nil,
                daysUntilExpiry: nil
            )
        }
    }

    // MARK: - Unpaid Utility Alerts (accumulative — all months)

    private func generateUnpaidUtilityAlerts(
        charges: [UtilityCharge], propertyName: String, propertyId: UUID,
        now: Date, calendar: Calendar
    ) -> [LocalAlert] {
        let currentDay = calendar.component(.day, from: now)

        return charges.map { charge in
            let monthsAgo =
                calendar.dateComponents([.month], from: charge.month, to: now).month ?? 0
            let severity: AlertSeverity
            switch monthsAgo {
            case 0: severity = currentDay > 5 ? .warning : .info
            case 1: severity = .warning
            default: severity = .critical
            }

            let monthLabel = charge.month.formatted(.dateTime.month(.wide).year())
            let typeName = charge.type?.displayName ?? charge.utilityType
            let roomName = charge.roomName

            return LocalAlert(
                id: "unpaid_utility_\(charge.id)",
                type: .unpaidUtility,
                severity: severity,
                title: String(
                    localized: "Pending \(typeName) — \(roomName)",
                    locale: LanguageService.currentLocale,
                    comment: "Alert title for unpaid utility charge"),
                message: monthLabel,
                propertyName: propertyName,
                actionLabel: String(
                    localized: "Mark as paid", locale: LanguageService.currentLocale,
                    comment: "Alert action to mark utility as paid"),
                relatedTenantId: nil,
                relatedPropertyId: propertyId,
                relatedIncomeId: nil,
                relatedUtilityChargeId: charge.id,
                daysUntilExpiry: nil
            )
        }
    }
}
