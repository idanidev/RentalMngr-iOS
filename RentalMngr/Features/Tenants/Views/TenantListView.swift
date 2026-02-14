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

    /// Contract time progress (0...1). 1 = just started, 0 = expired
    private var contractProgress: Double {
        guard let start = tenant.contractStartDate, let end = tenant.contractEndDate else {
            return 0
        }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let remaining = end.timeIntervalSince(Date())
        return max(0, min(1, remaining / total))
    }

    /// Days remaining on the contract
    private var daysRemaining: Int {
        tenant.contractEndDate?.daysUntil ?? 0
    }

    /// Color based on contract status
    private var statusColor: Color {
        switch tenant.contractStatus {
        case .active: return .green
        case .expiringSoon: return .orange
        case .expired: return .red
        case .noContract: return .gray
        }
    }

    /// Initials from tenant name
    private var initials: String {
        let parts = tenant.fullName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? "?"
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    /// Human-readable remaining time
    private var remainingLabel: String {
        if daysRemaining > 30 {
            let months = daysRemaining / 30
            let days = daysRemaining % 30
            if days == 0 {
                return "\(months) mes\(months == 1 ? "" : "es") restantes"
            }
            return "\(months) mes\(months == 1 ? "" : "es") y \(days) día\(days == 1 ? "" : "s")"
        } else if daysRemaining > 0 {
            return "\(daysRemaining) día\(daysRemaining == 1 ? "" : "s") restantes"
        } else if daysRemaining == 0 {
            return "¡Finaliza hoy!"
        } else {
            return "Expirado hace \(abs(daysRemaining)) días"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: Avatar + Name + Rent
            HStack(spacing: 12) {
                // Avatar with status ring
                ZStack {
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: contractProgress)
                        .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(initials)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(tenant.fullName)
                            .font(.headline)
                        if !tenant.active {
                            Text("Inactivo")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red.opacity(0.15), in: Capsule())
                                .foregroundStyle(.red)
                        }
                    }

                    // Room badge
                    if let room = tenant.room {
                        HStack(spacing: 4) {
                            Image(systemName: "bed.double.fill")
                                .font(.caption2)
                            Text(room.name)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                    }
                }

                Spacer()

                // Rent amount
                if let rent = tenant.effectiveMonthlyRent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(rent))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text("/mes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Contract section
            if let startDate = tenant.contractStartDate, let endDate = tenant.contractEndDate {
                VStack(spacing: 6) {
                    // Contract date range
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(startDate.dayMonthYear)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text("\(endDate.dayMonthYear)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(statusColor)
                        Spacer()
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(statusColor.opacity(0.15))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(statusColor)
                                .frame(width: max(0, geo.size.width * contractProgress), height: 6)
                        }
                    }
                    .frame(height: 6)

                    // Status label
                    HStack {
                        Text(tenant.contractStatus.label)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor)

                        Spacer()

                        Text(remainingLabel)
                            .font(.caption2)
                            .fontWeight(daysRemaining <= 0 ? .bold : .regular)
                            .foregroundStyle(daysRemaining <= 0 ? .red : .secondary)
                    }
                }
            } else {
                // No contract
                HStack(spacing: 4) {
                    Image(systemName: "doc.questionmark")
                        .font(.caption2)
                    Text("Sin contrato definido")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

            }

            // Contact info row
            if let phone = tenant.phone, !phone.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.caption2)
                    Text(phone)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
