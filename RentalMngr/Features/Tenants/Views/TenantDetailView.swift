import SwiftUI

struct TenantDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var tenant: Tenant
    @State private var showEditSheet = false
    @State private var showAssignSheet = false
    @State private var showRenewSheet = false

    init(tenant: Tenant) {
        _tenant = State(initialValue: tenant)
    }

    var body: some View {
        List {
            // Contact info
            Section("Contacto") {
                LabeledContent("Nombre", value: tenant.fullName)
                if let email = tenant.email, !email.isEmpty {
                    LabeledContent("Email", value: email)
                }
                if let phone = tenant.phone, !phone.isEmpty {
                    LabeledContent("Teléfono", value: phone)
                }
                if let dni = tenant.dni, !dni.isEmpty {
                    LabeledContent("DNI", value: dni)
                }
                if let address = tenant.currentAddress, !address.isEmpty {
                    LabeledContent("Dirección actual", value: address)
                }
            }

            // Assigned Room
            if let room = tenant.room {
                Section("Habitación asignada") {
                    LabeledContent("Habitación", value: room.name)
                    LabeledContent("Tipo", value: room.roomType == .privateRoom ? "Privada" : "Común")
                    LabeledContent("Renta habitación", value: formatCurrency(room.monthlyRent))
                    if let size = room.sizeSqm {
                        LabeledContent("Tamaño", value: "\(size) m²")
                    }
                }
            } else if tenant.active {
                Section("Habitación") {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .foregroundStyle(.orange)
                        Text("Sin habitación asignada")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Asignar") {
                            showAssignSheet = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            // Contract
            Section("Contrato") {
                if let start = tenant.contractStartDate {
                    LabeledContent("Inicio", value: start.shortFormatted)
                }
                if let months = tenant.contractMonths {
                    LabeledContent("Duración", value: "\(months) meses")
                }
                if let end = tenant.contractEndDate {
                    LabeledContent("Fin", value: end.shortFormatted)
                    HStack {
                        Text("Estado")
                        Spacer()
                        contractStatusBadge(for: tenant.contractStatus)
                    }
                }
                if let deposit = tenant.depositAmount {
                    LabeledContent("Fianza", value: formatCurrency(deposit))
                }
                // Use effective rent (from room if assigned, else from tenant)
                if let rent = tenant.effectiveMonthlyRent {
                    LabeledContent("Renta mensual", value: formatCurrency(rent))
                }
            }

            // Notes
            if let notes = tenant.notes, !notes.isEmpty {
                Section("Notas") {
                    Text(notes)
                }
            }

            if let contractNotes = tenant.contractNotes, !contractNotes.isEmpty {
                Section("Notas del contrato") {
                    Text(contractNotes)
                }
            }

            // Actions
            Section("Acciones") {
                Button {
                    showRenewSheet = true
                } label: {
                    Label("Renovar contrato", systemImage: "arrow.clockwise")
                }

                NavigationLink {
                    ContractView(tenant: tenant, propertyId: tenant.propertyId)
                } label: {
                    Label("Generar contrato PDF", systemImage: "doc.text")
                }

                if tenant.active {
                    Button(role: .destructive) {
                        Task {
                            try? await appState.tenantService.deactivateTenant(id: tenant.id)
                            tenant.active = false
                        }
                    } label: {
                        Label("Desactivar inquilino", systemImage: "person.slash")
                    }
                }
            }
        }
        .navigationTitle(tenant.fullName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                TenantFormView(propertyId: tenant.propertyId, tenant: tenant)
            }
        }
        .sheet(isPresented: $showAssignSheet) {
            // Reload tenant after assign
            Task {
                if let updated = try? await appState.tenantService.fetchTenant(id: tenant.id) {
                    tenant = updated
                }
            }
        } content: {
            NavigationStack {
                TenantAssignView(tenant: tenant, propertyId: tenant.propertyId)
            }
        }
        .confirmationDialog(
            "Renovar contrato", isPresented: $showRenewSheet, titleVisibility: .visible
        ) {
            Button("Renovar 6 meses") {
                renewContract(months: 6)
            }
            Button("Renovar 1 año") {
                renewContract(months: 12)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Selecciona la duración de la renovación")
        }
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
        }
    }

    private func renewContract(months: Int) {
        Task {
            // Optimistic update or fetch fresh data
            try? await appState.tenantService.renewContract(
                tenantId: tenant.id, contractMonths: months)
            if let updated = try? await appState.tenantService.fetchTenant(id: tenant.id) {
                tenant = updated
            }
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
