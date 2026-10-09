import SwiftUI

struct TenantDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var tenant: Tenant
    @State private var showEditSheet = false
    @State private var showAssignSheet = false
    @State private var showMoveSheet = false
    @State private var showRenewSheet = false
    @State private var pendingAction: DestructiveAction?
    @State private var errorMessage: String?

    init(tenant: Tenant) {
        _tenant = State(initialValue: tenant)
    }

    var body: some View {
        List {
            // Personal Info Section
            Section(
                String(localized: "Personal Information",
                    locale: LanguageService.currentLocale, comment: "Section header for tenant personal info")
            ) {
                LabeledContent(
                    String(localized: "Name", locale: LanguageService.currentLocale, comment: "Label for tenant name"),
                    value: tenant.fullName)
                if let email = tenant.email, !email.isEmpty {
                    LabeledContent(
                        String(localized: "Email", locale: LanguageService.currentLocale, comment: "Label for tenant email"), value: email)
                }
                if let phone = tenant.phone, !phone.isEmpty {
                    LabeledContent(
                        String(localized: "Phone", locale: LanguageService.currentLocale, comment: "Label for tenant phone"), value: phone)
                }
                if let dni = tenant.dni, !dni.isEmpty {
                    LabeledContent(
                        String(localized: "DNI/NIE", locale: LanguageService.currentLocale, comment: "Label for tenant ID document"),
                        value: dni)
                }
                if let address = tenant.currentAddress, !address.isEmpty {
                    LabeledContent(
                        String(localized: "Address", locale: LanguageService.currentLocale, comment: "Label for tenant address"),
                        value: address)
                }
            }

            // Room Section
            Section(String(localized: "Accommodation", locale: LanguageService.currentLocale, comment: "Section header in tenant detail"))
            {
                if let room = tenant.room {
                    LabeledContent(
                        String(localized: "Room", locale: LanguageService.currentLocale, comment: "Label for room name"), value: room.name)
                    if let rent = tenant.effectiveMonthlyRent {
                        LabeledContent(
                            String(localized: "Monthly Rent", locale: LanguageService.currentLocale, comment: "Label for monthly rent"),
                            value: rent.formatted(currencyCode: "EUR"))
                    }
                    if let deposit = tenant.depositAmount {
                        LabeledContent(
                            String(localized: "Deposit", locale: LanguageService.currentLocale, comment: "Label for deposit amount"),
                            value: deposit.formatted(currencyCode: "EUR"))
                    }
                } else {
                    Text(
                        String(localized: "Not assigned to any room",
                            locale: LanguageService.currentLocale, comment: "Placeholder when no room assigned")
                    )
                    .foregroundStyle(.secondary)
                    Button(
                        String(localized: "Assign to Room",
                            locale: LanguageService.currentLocale, comment: "Button to assign tenant to a room")
                    ) {
                        showAssignSheet = true
                    }
                }
            }

            // Contract Section
            Section(
                String(localized: "Contract Details", locale: LanguageService.currentLocale, comment: "Section header for contract details")
            ) {
                if let startDate = tenant.contractStartDate {
                    LabeledContent(
                        String(localized: "Start Date", locale: LanguageService.currentLocale, comment: "Label for contract start date"),
                        value: startDate.formatted(date: .abbreviated, time: .omitted)
                    )
                }
                if let endDate = tenant.contractEndDate {
                    LabeledContent(
                        String(localized: "End Date", locale: LanguageService.currentLocale, comment: "Label for contract end date"),
                        value: endDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent {
                        contractStatusBadge(for: tenant.contractStatus)
                    } label: {
                        Text(String(localized: "Status", locale: LanguageService.currentLocale, comment: "Label for contract status"))
                    }
                }
                LabeledContent(
                    String(localized: "Duration", locale: LanguageService.currentLocale, comment: "Label for contract duration"),
                    value: "\(tenant.contractMonths ?? 0) months")
            }

            // Notes Section
            if let notes = tenant.notes, !notes.isEmpty {
                Section(
                    String(localized: "General Notes", locale: LanguageService.currentLocale, comment: "Section header for general notes")
                ) {
                    Text(notes)
                }
            }

            if let contractNotes = tenant.contractNotes, !contractNotes.isEmpty {
                Section(
                    String(localized: "Contract Notes", locale: LanguageService.currentLocale, comment: "Section header for contract notes")
                ) {
                    Text(contractNotes)
                }
            }

            RentHistorySection(tenant: tenant) {
                await reloadTenant()
            }

            // Actions Section
            Section(String(localized: "Actions", locale: LanguageService.currentLocale, comment: "Section header for tenant actions")) {
                Button {
                    showRenewSheet = true
                } label: {
                    Label(
                        String(localized: "Renew Contract", locale: LanguageService.currentLocale, comment: "Button to renew tenant contract"),
                        systemImage: "arrow.clockwise")
                    .frame(maxWidth: hSize == .regular ? .infinity : nil, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .disabled(!tenant.active)

                Button {
                    showMoveSheet = true
                } label: {
                    Label(
                        String(localized: "Move Room", locale: LanguageService.currentLocale, comment: "Button to move tenant to another room"
                        ), systemImage: "arrow.right.arrow.left")
                    .frame(maxWidth: hSize == .regular ? .infinity : nil, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .disabled(!tenant.active)

                NavigationLink {
                    ContractView(tenant: tenant, propertyId: tenant.propertyId)
                } label: {
                    Label(
                        String(localized: "Generate Contract PDF",
                            locale: LanguageService.currentLocale, comment: "Button to generate contract PDF"), systemImage: "doc.text")
                    .frame(maxWidth: hSize == .regular ? .infinity : nil, alignment: .leading)
                    .contentShape(Rectangle())
                }

                if tenant.active {
                    Button(role: .destructive) {
                        pendingAction = endContractConfirmation
                    } label: {
                        Label(
                            String(localized: "Dar de baja el contrato",
                                locale: LanguageService.currentLocale, comment: "Button to end the tenant's contract and free the room"),
                            systemImage: "door.left.hand.open"
                        )
                        .frame(maxWidth: hSize == .regular ? .infinity : nil, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                } else {
                    Button {
                        Task {
                            do {
                                try await appState.tenantService.activateTenant(id: tenant.id)
                                tenant = try await appState.tenantService.fetchTenant(id: tenant.id)
                                appState.tenantDataDidChange()
                            } catch {
                                errorMessage = error.safeUserMessage
                            }
                        }
                    } label: {
                        Label(
                            String(localized: "Reactivate Tenant",
                                locale: LanguageService.currentLocale, comment: "Button to reactivate a deactivated tenant"),
                            systemImage: "person.badge.shield.checkmark.fill")
                        .frame(maxWidth: hSize == .regular ? .infinity : nil, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .frame(maxWidth: hSize == .regular ? 720 : .infinity)
        .frame(maxWidth: .infinity)
        .navigationTitle(tenant.fullName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit", locale: LanguageService.currentLocale, comment: "Edit button")) { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            Task {
                await reloadTenant()
            }
        } content: {
            NavigationStack {
                TenantFormView(propertyId: tenant.propertyId, tenant: tenant)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showAssignSheet) {
            Task {
                await reloadTenant()
            }
        } content: {
            NavigationStack {
                TenantAssignView(tenant: tenant, propertyId: tenant.propertyId)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveTenantView(
                tenant: tenant,
                propertyId: tenant.propertyId,
                roomService: appState.roomService,
                tenantService: appState.tenantService
            ) {
                Task {
                    await reloadTenant()
                }
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showRenewSheet) {
            Task {
                await reloadTenant()
            }
        } content: {
            RenewContractSheet(
                tenant: tenant,
                onRenew: { months in
                    try await appState.tenantService.renewContract(
                        tenantId: tenant.id, contractMonths: months, currentEndDate: tenant.contractEndDate)
                    // Antes se recargaba al cerrar la hoja, cuando ya había
                    // terminado la animación: se veían las fechas viejas un rato.
                    await reloadTenant()
                },
                onRentChange: { amount, from in
                    _ = try await appState.rentChangeService.recordChange(
                        tenantId: tenant.id, newAmount: amount, effectiveDate: from,
                        note: String(localized: "Renovación de contrato", locale: LanguageService.currentLocale,
                            comment: "Note stored with a rent change made at renewal"))
                })
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .destructiveConfirmation($pendingAction)
        .errorAlert($errorMessage)
    }

    /// Recarga el inquilino y, si algo ha cambiado, avisa al resto de pantallas.
    /// Si no cambió nada —una hoja cerrada sin guardar— no molesta a nadie.
    private func reloadTenant() async {
        guard let updated = try? await appState.tenantService.fetchTenant(id: tenant.id) else {
            return
        }
        if updated != tenant {
            tenant = updated
            appState.tenantDataDidChange()
        }
    }

    /// Dar de baja deja la habitación libre y al inquilino inactivo. Se dice qué
    /// habitación se libera y que no se borra nada, que es lo que preocupa.
    private var endContractConfirmation: DestructiveAction {
        let tenantId = tenant.id
        let roomId = tenant.room?.id
        let message: String
        if let habitacion = tenant.room?.name {
            message = String(localized: "\(habitacion) queda libre y \(tenant.fullName) pasa a inactivo. No se borra nada: su ficha, su contrato y sus pagos se conservan, y puedes reactivarle cuando quieras.",
                locale: LanguageService.currentLocale, comment: "End contract confirmation, tenant with a room")
        } else {
            message = String(localized: "\(tenant.fullName) pasa a inactivo. No se borra nada: su ficha, su contrato y sus pagos se conservan, y puedes reactivarle cuando quieras.",
                locale: LanguageService.currentLocale, comment: "End contract confirmation, tenant without a room")
        }
        return DestructiveAction(
            title: String(localized: "¿Dar de baja el contrato de \(tenant.fullName)?",
                locale: LanguageService.currentLocale, comment: "End contract confirmation title"),
            message: message,
            confirmLabel: String(localized: "Dar de baja", locale: LanguageService.currentLocale,
                comment: "End contract confirmation button"),
            icon: "door.left.hand.open",
            perform: {
                do {
                    try await appState.tenantService.endContract(tenantId: tenantId, roomId: roomId)
                    tenant = try await appState.tenantService.fetchTenant(id: tenantId)
                    appState.tenantDataDidChange()
                } catch where error.isCancellation {
                    return
                } catch {
                    errorMessage = error.safeUserMessage
                }
            })
    }

    @ViewBuilder
    private func contractStatusBadge(for status: ContractStatus) -> some View {
        Text(status.label)
            .font(.subheadline.bold())
            .fontWeight(.semibold)
            .foregroundStyle(contractStatusColor(status))
    }

    private func contractStatusColor(_ status: ContractStatus) -> Color {
        switch status {
        case .active: .green
        case .expiringSoon: .orange
        case .expired: .red
        case .noContract: .secondary
        case .terminated: .secondary
        }
    }


}
