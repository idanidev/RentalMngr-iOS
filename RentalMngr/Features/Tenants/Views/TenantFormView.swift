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
        .navigationTitle(tenant == nil ? "Nuevo inquilino" : "Editar inquilino")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    Task {
                        if let _ = await viewModel?.save() {
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
                    propertyId: propertyId,
                    tenantService: appState.tenantService,
                    tenant: tenant
                )
            }
        }
    }

    @ViewBuilder
    private func formContent(_ vm: TenantFormViewModel) -> some View {
        Form {
            Section("Datos personales") {
                TextField("Nombre completo *", text: Binding(get: { vm.fullName }, set: { vm.fullName = $0 }))
                TextField("Email", text: Binding(get: { vm.email }, set: { vm.email = $0 }))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Teléfono", text: Binding(get: { vm.phone }, set: { vm.phone = $0 }))
                    .keyboardType(.phonePad)
                TextField("DNI/NIE", text: Binding(get: { vm.dni }, set: { vm.dni = $0 }))
                TextField("Dirección actual", text: Binding(get: { vm.currentAddress }, set: { vm.currentAddress = $0 }))
            }

            Section("Contrato") {
                DatePicker("Inicio", selection: Binding(get: { vm.contractStartDate }, set: { vm.contractStartDate = $0 }), displayedComponents: .date)

                Stepper("Duración: \(vm.contractMonths) meses", value: Binding(get: { vm.contractMonths }, set: { vm.contractMonths = $0 }), in: 1...60)

                DatePicker("Fin", selection: Binding(get: { vm.contractEndDate }, set: { vm.contractEndDate = $0 }), displayedComponents: .date)

                TextField("Fianza (€)", text: Binding(get: { vm.depositAmount }, set: { vm.depositAmount = $0 }))
                    .keyboardType(.decimalPad)

                TextField("Renta mensual (€)", text: Binding(get: { vm.monthlyRent }, set: { vm.monthlyRent = $0 }))
                    .keyboardType(.decimalPad)
            }

            Section("Notas") {
                TextField("Notas generales", text: Binding(get: { vm.notes }, set: { vm.notes = $0 }), axis: .vertical)
                    .lineLimit(3...6)
                TextField("Notas del contrato", text: Binding(get: { vm.contractNotes }, set: { vm.contractNotes = $0 }), axis: .vertical)
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
