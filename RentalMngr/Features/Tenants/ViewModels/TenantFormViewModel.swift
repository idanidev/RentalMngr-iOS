import Foundation

@Observable
final class TenantFormViewModel {
    var fullName = ""
    var email = ""
    var phone = ""
    var dni = ""
    var contractStartDate = Date()
    var contractMonths = 6
    var contractEndDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    var depositAmount = ""
    var monthlyRent = ""
    var currentAddress = ""
    var notes = ""
    var contractNotes = ""
    var isLoading = false
    var errorMessage: String?

    let isEditing: Bool
    let propertyId: UUID
    private var tenantId: UUID?
    private var isActive = true
    private let tenantService: TenantService

    init(propertyId: UUID, tenantService: TenantService, tenant: Tenant? = nil) {
        self.propertyId = propertyId
        self.tenantService = tenantService
        if let tenant {
            self.isEditing = true
            self.tenantId = tenant.id
            self.fullName = tenant.fullName
            self.email = tenant.email ?? ""
            self.phone = tenant.phone ?? ""
            self.dni = tenant.dni ?? ""
            self.contractStartDate = tenant.contractStartDate ?? Date()
            self.contractMonths = tenant.contractMonths ?? 6
            self.contractEndDate = tenant.contractEndDate ?? Date()
            self.depositAmount = tenant.depositAmount.map { "\($0)" } ?? ""
            self.monthlyRent = tenant.monthlyRent.map { "\($0)" } ?? ""
            self.currentAddress = tenant.currentAddress ?? ""
            self.notes = tenant.notes ?? ""
            self.contractNotes = tenant.contractNotes ?? ""
            self.isActive = tenant.active
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
                var tenant = Tenant(
                    id: tenantId, propertyId: propertyId,
                    fullName: fullName.trimmingCharacters(in: .whitespaces),
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    dni: dni.isEmpty ? nil : dni,
                    contractStartDate: contractStartDate,
                    contractMonths: contractMonths,
                    contractEndDate: contractEndDate,
                    depositAmount: Decimal(string: depositAmount),
                    monthlyRent: Decimal(string: monthlyRent),
                    currentAddress: currentAddress.isEmpty ? nil : currentAddress,
                    notes: notes.isEmpty ? nil : notes,
                    contractNotes: contractNotes.isEmpty ? nil : contractNotes,
                    active: isActive,
                    createdAt: nil, updatedAt: nil
                )
                let result = try await tenantService.updateTenant(tenant)
                isLoading = false
                return result
            } else {
                let result = try await tenantService.createTenant(
                    propertyId: propertyId,
                    fullName: fullName.trimmingCharacters(in: .whitespaces),
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    dni: dni.isEmpty ? nil : dni,
                    contractStartDate: contractStartDate,
                    contractMonths: contractMonths,
                    contractEndDate: contractEndDate,
                    depositAmount: Decimal(string: depositAmount),
                    monthlyRent: Decimal(string: monthlyRent),
                    currentAddress: currentAddress.isEmpty ? nil : currentAddress,
                    notes: notes.isEmpty ? nil : notes,
                    contractNotes: contractNotes.isEmpty ? nil : contractNotes
                )
                isLoading = false
                return result
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
