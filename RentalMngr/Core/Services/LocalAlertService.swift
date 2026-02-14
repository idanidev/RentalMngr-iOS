import Foundation

/// Generates local alerts by scanning existing data — no server-side logic needed.
final class LocalAlertService {
    private let tenantService: TenantService
    private let financeService: FinanceService
    private let propertyService: PropertyService

    init(
        tenantService: TenantService, financeService: FinanceService,
        propertyService: PropertyService
    ) {
        self.tenantService = tenantService
        self.financeService = financeService
        self.propertyService = propertyService
    }

    /// Generate all local alerts across all properties
    func generateAlerts() async -> [LocalAlert] {
        var alerts: [LocalAlert] = []

        do {
            let properties = try await propertyService.fetchProperties()

            // Generate contract alerts from tenants
            for property in properties {
                let tenants = try await tenantService.fetchTenants(propertyId: property.id)
                let contractAlerts = generateContractAlerts(
                    tenants: tenants, propertyName: property.name, propertyId: property.id)
                alerts.append(contentsOf: contractAlerts)

                // Generate unpaid rent alerts from income
                let now = Date()
                let calendar = Calendar.current
                let startOfMonth = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: now))!
                let endOfMonth = calendar.date(
                    byAdding: DateComponents(month: 1, second: -1), to: startOfMonth)!

                let income = try await financeService.fetchIncome(
                    propertyId: property.id,
                    startDate: startOfMonth,
                    endDate: endOfMonth
                )
                let unpaidAlerts = generateUnpaidAlerts(
                    income: income, propertyName: property.name, propertyId: property.id)
                alerts.append(contentsOf: unpaidAlerts)
            }
        } catch {
            print("[LocalAlertService] Error generating alerts: \(error)")
        }

        // Sort by severity (critical first) then by type
        return alerts.sorted { $0.severity > $1.severity }
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
                // Contract expired
                alerts.append(
                    LocalAlert(
                        id: "contract_expired_\(tenant.id)",
                        type: .contractExpired,
                        severity: .critical,
                        title: "Contrato expirado",
                        message: "\(tenant.fullName) — contrato venció hace \(abs(days)) días",
                        propertyName: propertyName,
                        actionLabel: "Renovar",
                        relatedTenantId: tenant.id,
                        relatedPropertyId: propertyId,
                        relatedIncomeId: nil,
                        daysUntilExpiry: days
                    ))
            } else if days <= 30 {
                // Contract expiring soon
                let severity: AlertSeverity = days <= 7 ? .critical : .warning
                alerts.append(
                    LocalAlert(
                        id: "contract_expiring_\(tenant.id)",
                        type: .contractExpiring,
                        severity: severity,
                        title: days == 0 ? "Contrato vence hoy" : "Contrato vence en \(days) días",
                        message: "\(tenant.fullName) en \(tenant.room?.name ?? "sin habitación")",
                        propertyName: propertyName,
                        actionLabel: "Renovar",
                        relatedTenantId: tenant.id,
                        relatedPropertyId: propertyId,
                        relatedIncomeId: nil,
                        daysUntilExpiry: days
                    ))
            }
        }
        return alerts
    }

    // MARK: - Unpaid Rent Alerts

    private func generateUnpaidAlerts(income: [Income], propertyName: String, propertyId: UUID)
        -> [LocalAlert]
    {
        let now = Date()
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: now)

        return income.filter { !$0.paid }.map { entry in
            // If past the 5th of the month, it's more urgent
            let severity: AlertSeverity = currentDay > 5 ? .warning : .info
            let roomName = entry.room?.name ?? "Habitación"
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "EUR"
            let amountStr =
                formatter.string(from: entry.amount as NSDecimalNumber) ?? "\(entry.amount)€"

            return LocalAlert(
                id: "unpaid_\(entry.id)",
                type: .unpaidRent,
                severity: severity,
                title: "Pago pendiente — \(roomName)",
                message: "\(amountStr) sin cobrar este mes",
                propertyName: propertyName,
                actionLabel: "Marcar pagado",
                relatedTenantId: nil,
                relatedPropertyId: propertyId,
                relatedIncomeId: entry.id,
                daysUntilExpiry: nil
            )
        }
    }
}
