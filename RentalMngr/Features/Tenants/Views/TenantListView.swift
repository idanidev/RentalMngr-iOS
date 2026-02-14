import SwiftUI
import UIKit

struct TenantListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: TenantListViewModel?
    @State private var showAddSheet = false
    @State private var didAttemptLoad = false
    @State private var showRenewalConfirmation = false
    @State private var selectedTenantForRenewal: Tenant?
    let propertyId: UUID

    var body: some View {
        Group {
            if let vm = viewModel {
                tenantContent(vm)
            } else {
                ProgressView("Cargando inquilinos...")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            if let vm = viewModel {
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Toggle(
                            isOn: Binding(get: { vm.showInactive }, set: { vm.showInactive = $0 })
                        ) {
                            Label("Mostrar inactivos", systemImage: "person.slash")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let vm = viewModel { Task { await vm.loadTenants() } }
        } content: {
            NavigationStack {
                TenantFormView(propertyId: propertyId, tenant: nil)
            }
        }
        .onAppear {
            guard !didAttemptLoad else { return }
            didAttemptLoad = true
            print("[TenantListView] onAppear fired for propertyId: \(propertyId)")
            if viewModel == nil {
                viewModel = TenantListViewModel(
                    propertyId: propertyId,
                    tenantService: appState.tenantService,
                    roomService: appState.roomService
                )
            }
            Task {
                await viewModel?.loadTenants()
            }
        }
    }

    @ViewBuilder
    private func tenantContent(_ vm: TenantListViewModel) -> some View {
        if vm.isLoading {
            ProgressView("Cargando inquilinos...")
        } else if let error = vm.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Error al cargar inquilinos")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Reintentar") {
                    Task { await vm.loadTenants() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else if vm.filteredTenants.isEmpty {
            VStack(spacing: 12) {
                EmptyStateView(
                    icon: "person.crop.circle",
                    title: "Sin inquilinos",
                    subtitle: vm.showInactive
                        ? "No hay inquilinos para esta propiedad"
                        : "No hay inquilinos activos (activa 'Mostrar inactivos')",
                    actionTitle: "Añadir inquilino"
                ) {
                    showAddSheet = true
                }
                // Debug info (temporary)
                Text(
                    verbatim:
                        "DEBUG: propertyId=\(propertyId.uuidString.prefix(8))... total=\(vm.tenants.count) active=\(vm.tenants.filter(\.active).count) didLoad=\(didAttemptLoad)"
                )
                .font(.caption2)
                .foregroundStyle(.red)
                Button("Reintentar carga") {
                    Task { await vm.loadTenants() }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        } else {
            List {
                ForEach(vm.filteredTenants) { tenant in
                    NavigationLink(value: tenant) {
                        TenantRow(tenant: tenant)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if let phone = tenant.phone, !phone.isEmpty,
                            let url = URL(string: "tel:\(phone)")
                        {
                            Button {
                                UIApplication.shared.open(url)
                            } label: {
                                Label("Llamar", systemImage: "phone.fill")
                            }
                            .tint(.green)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if tenant.active {
                            Button(role: .destructive) {
                                Task { await vm.deactivateTenant(tenant) }
                            } label: {
                                Label("Desactivar", systemImage: "person.slash")
                            }

                            Button {
                                selectedTenantForRenewal = tenant
                                showRenewalConfirmation = true
                            } label: {
                                Label("Renovar", systemImage: "arrow.clockwise")
                            }
                            .tint(.blue)

                            NavigationLink {
                                ContractView(tenant: tenant, propertyId: propertyId)
                            } label: {
                                Label("Contrato", systemImage: "doc.text")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationDestination(for: Tenant.self) { tenant in
                TenantDetailView(tenant: tenant)
            }
            .confirmationDialog(
                "Renovar contrato", isPresented: $showRenewalConfirmation, titleVisibility: .visible
            ) {
                Button("Renovar 6 meses") {
                    if let t = selectedTenantForRenewal {
                        Task { await vm.renewContract(tenant: t, months: 6) }
                    }
                }
                Button("Renovar 1 año") {
                    if let t = selectedTenantForRenewal {
                        Task { await vm.renewContract(tenant: t, months: 12) }
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Selecciona la duración de la renovación")
            }
        }
    }
}

private struct TenantRow: View {
    let tenant: Tenant

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tenant.fullName)
                        .font(.headline)
                    if !tenant.active {
                        Text("Inactivo")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.2), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }
                // Show assigned room if available
                if let room = tenant.room {
                    HStack(spacing: 4) {
                        Image(systemName: "bed.double")
                            .font(.caption2)
                        Text(room.name)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                if let endDate = tenant.contractEndDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("Contrato hasta \(endDate.shortFormatted)")
                            .font(.caption)
                    }
                    .foregroundStyle(endDate.isExpiringSoon ? .orange : .secondary)
                }
            }
            Spacer()
            if let rent = tenant.effectiveMonthlyRent {
                Text(formatCurrency(rent))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
