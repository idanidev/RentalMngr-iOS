import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                dashboardContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Inicio")
        .task {
            if viewModel == nil {
                viewModel = DashboardViewModel(
                    propertyService: appState.propertyService,
                    roomService: appState.roomService,
                    tenantService: appState.tenantService,
                    financeService: appState.financeService
                )
            }
            await viewModel?.loadDashboard()
        }
    }

    @ViewBuilder
    private func dashboardContent(_ vm: DashboardViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if vm.isLoading && vm.properties.isEmpty {
                    LoadingView()
                } else if let error = vm.errorMessage, vm.properties.isEmpty {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "Error",
                        subtitle: error,
                        actionTitle: "Reintentar"
                    ) {
                        Task { await vm.loadDashboard() }
                    }
                } else {
                    statsGrid(vm)
                    propertiesSection(vm)
                    expiringContractsSection(vm)
                }
            }
            .padding()
        }
        .refreshable {
            await vm.loadDashboard()
        }
    }

    @ViewBuilder
    private func statsGrid(_ vm: DashboardViewModel) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Propiedades", value: "\(vm.properties.count)", icon: "building.2.fill",
                color: .blue)
            StatCard(
                title: "Ocupación", value: String(format: "%.0f%%", vm.occupancyRate),
                icon: "person.2.fill", color: .green)
            StatCard(
                title: "Habitaciones", value: "\(vm.occupiedRooms)/\(vm.totalRooms)",
                icon: "bed.double.fill", color: .orange)
            StatCard(
                title: "Ingresos/mes", value: formatCurrency(vm.totalMonthlyIncome),
                icon: "eurosign.circle.fill", color: .mint)
            StatCard(
                title: "Pagos pendientes", value: "\(vm.pendingPayments)", icon: "clock.fill",
                color: vm.pendingPayments > 0 ? .red : .gray)
            StatCard(
                title: "Contratos por vencer", value: "\(vm.expiringContracts.count)",
                icon: "doc.text.fill", color: vm.expiringContracts.isEmpty ? .gray : .orange)
        }
    }

    @ViewBuilder
    private func propertiesSection(_ vm: DashboardViewModel) -> some View {
        if !vm.properties.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mis propiedades")
                    .font(.headline)

                ForEach(vm.properties) { property in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(property.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(property.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "building.2.fill")
                                    .foregroundStyle(.blue)
                            }

                            HStack(spacing: 16) {
                                Label(
                                    "\(property.occupiedPrivateRooms.count)/\(property.privateRooms.count) hab.",
                                    systemImage: "bed.double"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                if property.privateRooms.count > 0 {
                                    Text(String(format: "%.0f%%", property.occupancyRate))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(
                                            property.occupancyRate >= 80 ? .green : .orange)
                                }

                                Spacer()

                                if property.monthlyRevenue > 0 {
                                    Text(formatCurrency(property.monthlyRevenue))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.mint)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func expiringContractsSection(_ vm: DashboardViewModel) -> some View {
        if !vm.expiringContracts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Contratos por vencer")
                    .font(.headline)

                ForEach(vm.expiringContracts) { tenant in
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tenant.fullName)
                                    .fontWeight(.semibold)
                                if let endDate = tenant.contractEndDate {
                                    Text("Vence: \(endDate.shortFormatted)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(endDate.daysUntil) días restantes")
                                        .font(.caption)
                                        .foregroundStyle(endDate.daysUntil <= 7 ? .red : .orange)
                                }
                            }
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
