import SwiftUI

struct TenantDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var tenant: Tenant
    @State private var showEditSheet = false
    @State private var showAssignSheet = false
    @State private var showMoveSheet = false
    @State private var showRenewSheet = false
    @State private var showDeactivateConfirmation = false
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

            // Actions Section
            Section(String(localized: "Actions", locale: LanguageService.currentLocale, comment: "Section header for tenant actions")) {
                Button {
                    showRenewSheet = true
                } label: {
                    Label(
                        String(localized: "Renew Contract", locale: LanguageService.currentLocale, comment: "Button to renew tenant contract"),
                        systemImage: "arrow.clockwise")
                }
                .disabled(!tenant.active)

                Button {
                    showMoveSheet = true
                } label: {
                    Label(
                        String(localized: "Move Room", locale: LanguageService.currentLocale, comment: "Button to move tenant to another room"
                        ), systemImage: "arrow.right.arrow.left")
                }
                .disabled(!tenant.active)

                NavigationLink {
                    ContractView(tenant: tenant, propertyId: tenant.propertyId)
                } label: {
                    Label(
                        String(localized: "Generate Contract PDF",
                            locale: LanguageService.currentLocale, comment: "Button to generate contract PDF"), systemImage: "doc.text")
                }

                if tenant.active {
                    Button(role: .destructive) {
                        showDeactivateConfirmation = true
                    } label: {
                        Label(
                            String(localized: "Deactivate Tenant",
                                locale: LanguageService.currentLocale, comment: "Button to deactivate tenant"), systemImage: "person.slash"
                        )
                    }
                } else {
                    Button {
                        Task {
                            do {
                                try await appState.tenantService.activateTenant(id: tenant.id)
                                tenant = try await appState.tenantService.fetchTenant(id: tenant.id)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Label(
                            String(localized: "Reactivate Tenant",
                                locale: LanguageService.currentLocale, comment: "Button to reactivate a deactivated tenant"),
                            systemImage: "person.badge.shield.checkmark.fill")
                    }
                }
            }
        }
        .navigationTitle(tenant.fullName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit", locale: LanguageService.currentLocale, comment: "Edit button")) { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            Task {
                if let updated = try? await appState.tenantService.fetchTenant(id: tenant.id) {
                    tenant = updated
                }
            }
        } content: {
            NavigationStack {
                TenantFormView(propertyId: tenant.propertyId, tenant: tenant)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showAssignSheet) {
            Task {
                if let updated = try? await appState.tenantService.fetchTenant(id: tenant.id) {
                    tenant = updated
                }
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
                    if let updated = try? await appState.tenantService.fetchTenant(id: tenant.id) {
                        tenant = updated
                    }
                }
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showRenewSheet) {
            Task {
                if let updated = try? await appState.tenantService.fetchTenant(id: tenant.id) {
                    tenant = updated
                }
            }
        } content: {
            RenewContractSheet(tenant: tenant) { months in
                try await appState.tenantService.renewContract(
                    tenantId: tenant.id, contractMonths: months, currentEndDate: tenant.contractEndDate)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .confirmationDialog(
            String(localized: "Deactivate Tenant?",
                locale: LanguageService.currentLocale, comment: "Dialog title for deactivate tenant confirmation"),
            isPresented: $showDeactivateConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "Deactivate", locale: LanguageService.currentLocale, comment: "Destructive button to confirm deactivation"),
                role: .destructive
            ) {
                Task {
                    do {
                        try await appState.tenantService.deactivateTenant(id: tenant.id)
                        tenant.active = false
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button"), role: .cancel) {}
        } message: {
            Text(
                String(localized: "This will mark the tenant as inactive.",
                    locale: LanguageService.currentLocale, comment: "Message in deactivate tenant dialog"))
        }
        .errorAlert($errorMessage)
    }

    @ViewBuilder
    private func contractStatusBadge(for status: ContractStatus) -> some View {
        Text(status.label)
            .font(.subheadline)
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
