import Auth
import Foundation
import Supabase

@MainActor @Observable
final class TenantFormViewModel {
    var fullName = ""
    var email = ""
    var phone = ""
    var dni = ""
    var contractStartDate = Date() {
        didSet { updateEndDate() }
    }
    var contractMonths = 6 {
        didSet { updateEndDate() }
    }
    var contractEndDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    private func updateEndDate() {
        if let newDate = Calendar.current.date(
            byAdding: .month, value: contractMonths, to: contractStartDate)
        {
            contractEndDate = newDate
        }
    }
    var depositAmount = ""
    var monthlyRent = ""
    var currentAddress = ""
    var notes = ""
    var contractNotes = ""
    var hasContract = false
    var isLoading = false
    var errorMessage: String?

    let propertyId: UUID
    let isEditing: Bool
    private let tenantService: TenantServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private var tenantId: UUID?
    private var isActive = true

    init(
        tenantService: TenantServiceProtocol,
        notificationService: NotificationServiceProtocol,
        propertyId: UUID,
        tenant: Tenant? = nil
    ) {
        self.propertyId = propertyId
        self.tenantService = tenantService
        self.notificationService = notificationService
        if let tenant {
            self.isEditing = true
            self.tenantId = tenant.id
            self.fullName = tenant.fullName
            self.email = tenant.email ?? ""
            self.phone = tenant.phone ?? ""
            self.dni = tenant.dni ?? ""
            self.isActive = tenant.active

            let hasAnyContractDetail =
                tenant.contractStartDate != nil || tenant.contractEndDate != nil
                || tenant.monthlyRent != nil || tenant.depositAmount != nil
                || tenant.contractMonths != nil
            self.hasContract = hasAnyContractDetail

            self.contractStartDate = tenant.contractStartDate ?? Date()
            self.contractMonths = tenant.contractMonths ?? 6
            self.contractEndDate =
                tenant.contractEndDate ?? Calendar.current.date(
                    byAdding: .month, value: self.contractMonths, to: self.contractStartDate)
                ?? Date()
            self.depositAmount = tenant.depositAmount?.description ?? ""
            self.monthlyRent = tenant.monthlyRent?.description ?? ""
            self.currentAddress = tenant.currentAddress ?? ""
            self.notes = tenant.notes ?? ""
            self.contractNotes = tenant.contractNotes ?? ""
        } else {
            self.isEditing = false
        }
    }

    var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func save() async -> Tenant? {
        isLoading = true
        errorMessage = nil
        do {
            if isEditing, let tenantId {
                let tenant = Tenant(
                    id: tenantId, propertyId: propertyId,
                    fullName: fullName.trimmingCharacters(in: .whitespaces),
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    dni: dni.isEmpty ? nil : dni,
                    contractStartDate: hasContract ? contractStartDate : nil,
                    contractMonths: hasContract ? contractMonths : nil,
                    contractEndDate: hasContract ? contractEndDate : nil,
                    depositAmount: hasContract
                        ? parseDecimal(depositAmount)
                        : nil,
                    monthlyRent: hasContract
                        ? parseDecimal(monthlyRent)
                        : nil,
                    currentAddress: currentAddress.isEmpty ? nil : currentAddress,
                    notes: notes.isEmpty ? nil : notes,
                    contractNotes: contractNotes.isEmpty || !hasContract ? nil : contractNotes,
                    active: isActive,
                    createdAt: nil, updatedAt: nil
                )
                let result = try await tenantService.updateTenant(tenant)

                if let endDate = result.contractEndDate,
                    let userId = SupabaseService.shared.client.auth.currentUser?.id
                {
                    let settings = try? await notificationService.fetchOrCreateSettings(
                        userId: userId)
                    let alertDays = settings?.contractAlertDays ?? [30, 15, 7]
                    await notificationService.scheduleContractExpiry(
                        tenantName: result.fullName,
                        expiryDate: endDate,
                        tenantId: result.id,
                        alertDays: alertDays
                    )
                }

                isLoading = false
                return result
            } else {
                let params = CreateTenantParams(
                    propertyId: propertyId,
                    fullName: fullName.trimmingCharacters(in: .whitespaces),
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    dni: dni.isEmpty ? nil : dni,
                    contractStartDate: hasContract ? contractStartDate : nil,
                    contractMonths: hasContract ? contractMonths : nil,
                    contractEndDate: hasContract ? contractEndDate : nil,
                    depositAmount: hasContract
                        ? Decimal(string: depositAmount.replacingOccurrences(of: ",", with: "."))
                        : nil,
                    monthlyRent: hasContract
                        ? Decimal(string: monthlyRent.replacingOccurrences(of: ",", with: "."))
                        : nil,
                    currentAddress: currentAddress.isEmpty ? nil : currentAddress,
                    notes: notes.isEmpty ? nil : notes,
                    contractNotes: contractNotes.isEmpty || !hasContract ? nil : contractNotes
                )
                let result = try await tenantService.createTenant(params)

                if let endDate = result.contractEndDate,
                    let userId = SupabaseService.shared.client.auth.currentUser?.id
                {
                    let settings = try? await notificationService.fetchOrCreateSettings(
                        userId: userId)
                    let alertDays = settings?.contractAlertDays ?? [30, 15, 7]
                    await notificationService.scheduleContractExpiry(
                        tenantName: result.fullName,
                        expiryDate: endDate,
                        tenantId: result.id,
                        alertDays: alertDays
                    )
                }

                isLoading = false
                return result
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    private func parseDecimal(_ text: String) -> Decimal? {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.isEmpty { return nil }

        // Try user's current locale first
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: cleanText) {
            return number.decimalValue
        }

        // Try fallback replacements if it fails
        let dotReplaced = cleanText.replacingOccurrences(of: ",", with: ".")
        if let dec = Decimal(string: dotReplaced) {
            return dec
        }

        let commaReplaced = cleanText.replacingOccurrences(of: ".", with: ",")
        if let dec = Decimal(string: commaReplaced, locale: Locale(identifier: "es_ES")) {
            return dec
        }

        return nil
    }
}
