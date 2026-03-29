import SwiftUI

struct TenantFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TenantFormViewModel?

    let propertyId: UUID
    let tenant: Tenant?

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(
            tenant == nil
                ? String(localized: "New tenant", locale: LanguageService.currentLocale, comment: "Navigation title for new tenant form")
                : String(localized: "Edit tenant", locale: LanguageService.currentLocale, comment: "Navigation title for edit tenant form")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save", locale: LanguageService.currentLocale, comment: "Save button")) {
                    Task {
                        if await viewModel?.save() != nil {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel?.isFormValid != true || viewModel?.isLoading == true)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TenantFormViewModel(
                    tenantService: appState.tenantService,
                    notificationService: appState.notificationService,
                    propertyId: propertyId,
                    tenant: tenant
                )
            }
        }
    }

    @ViewBuilder
    private func formContent(_ vm: TenantFormViewModel) -> some View {
        Form {
            Section(
                String(localized: "Personal details",
                    locale: LanguageService.currentLocale, comment: "Section header for tenant personal information")
            ) {
                TextField(
                    String(localized: "Full name *", locale: LanguageService.currentLocale, comment: "Placeholder for tenant full name field"),
                    text: Binding(get: { vm.fullName }, set: { vm.fullName = $0 }))
                TextField("Email", text: Binding(get: { vm.email }, set: { vm.email = $0 }))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField(
                    String(localized: "Phone", locale: LanguageService.currentLocale, comment: "Placeholder for phone number field"),
                    text: Binding(get: { vm.phone }, set: { vm.phone = $0 })
                )
                .keyboardType(.phonePad)
                TextField("DNI/NIE", text: Binding(get: { vm.dni }, set: { vm.dni = $0 }))
                TextField(
                    String(localized: "Current address",
                        locale: LanguageService.currentLocale, comment: "Placeholder for tenant current address field"),
                    text: Binding(get: { vm.currentAddress }, set: { vm.currentAddress = $0 }))
            }

            Section(
                String(localized: "Contract", locale: LanguageService.currentLocale, comment: "Section header for tenant contract details")
            ) {
                Toggle(
                    String(localized: "Include Contract Details",
                        locale: LanguageService.currentLocale, comment: "Toggle for contract details"),
                    isOn: Binding(get: { vm.hasContract }, set: { vm.hasContract = $0 }))

                if vm.hasContract {
                    DatePicker(
                        String(localized: "Start", locale: LanguageService.currentLocale, comment: "Label for contract start date"),
                        selection: Binding(
                            get: { vm.contractStartDate }, set: { vm.contractStartDate = $0 }),
                        displayedComponents: .date)

                    Stepper(
                        String(localized: "Duration: \(vm.contractMonths) months",
                            locale: LanguageService.currentLocale, comment: "Stepper label showing contract duration in months"),
                        value: Binding(get: { vm.contractMonths }, set: { vm.contractMonths = $0 }),
                        in: 1...60)

                    DatePicker(
                        String(localized: "End", locale: LanguageService.currentLocale, comment: "Label for contract end date"),
                        selection: Binding(
                            get: { vm.contractEndDate }, set: { vm.contractEndDate = $0 }),
                        displayedComponents: .date)

                    TextField(
                        String(localized: "Deposit (€)",
                            locale: LanguageService.currentLocale, comment: "Placeholder for deposit amount field"),
                        text: Binding(get: { vm.depositAmount }, set: { vm.depositAmount = $0 })
                    )
                    .keyboardType(.decimalPad)

                    TextField(
                        String(localized: "Monthly rent (€)",
                            locale: LanguageService.currentLocale, comment: "Placeholder for monthly rent field"),
                        text: Binding(get: { vm.monthlyRent }, set: { vm.monthlyRent = $0 })
                    )
                    .keyboardType(.decimalPad)
                }
            }

            Section(String(localized: "Notes", locale: LanguageService.currentLocale, comment: "Section header for tenant notes")) {
                TextField(
                    String(localized: "General notes", locale: LanguageService.currentLocale, comment: "Placeholder for general notes field"),
                    text: Binding(get: { vm.notes }, set: { vm.notes = $0 }),
                    axis: .vertical
                )
                .lineLimit(3...6)
                TextField(
                    String(localized: "Contract notes", locale: LanguageService.currentLocale, comment: "Placeholder for contract notes field"
                    ),
                    text: Binding(get: { vm.contractNotes }, set: { vm.contractNotes = $0 }),
                    axis: .vertical
                )
                .lineLimit(3...6)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .loadingOverlay(vm.isLoading)
    }
}
