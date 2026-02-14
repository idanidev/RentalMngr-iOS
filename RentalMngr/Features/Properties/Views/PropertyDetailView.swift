import SwiftUI

struct PropertyDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: PropertyDetailViewModel?
    @State private var showEditSheet = false
    @State private var showSharingSheet = false

    let property: Property

    var body: some View {
        Group {
            if let vm = viewModel {
                detailContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(property.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button {
                        showSharingSheet = true
                    } label: {
                        Label("Compartir", systemImage: "person.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let vm = viewModel { Task { await vm.refreshData() } }
        } content: {
            NavigationStack {
                PropertyFormView(property: property)
            }
        }
        .sheet(isPresented: $showSharingSheet) {
            NavigationStack {
                PropertySharingView(property: property)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = PropertyDetailViewModel(
                    property: property,
                    propertyService: appState.propertyService,
                    roomService: appState.roomService,
                    tenantService: appState.tenantService
                )
            }
            await viewModel?.loadData()
        }
    }

    @ViewBuilder
    private func detailContent(_ vm: PropertyDetailViewModel) -> some View {
        VStack(spacing: 0) {
            // Property stats header
            propertyStatsHeader(vm)

            // Tab Picker
            Picker(
                "Sección", selection: Binding(get: { vm.selectedTab }, set: { vm.selectedTab = $0 })
            ) {
                ForEach(PropertyTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Content
            Group {
                switch vm.selectedTab {
                case .rooms:
                    RoomListView(propertyId: property.id, rooms: vm.rooms)
                case .tenants:
                    TenantListView(propertyId: property.id)
                case .finances:
                    FinanceSummaryView(propertyId: property.id)
                case .roomie:
                    RoomieTabView(propertyId: property.id)
                }
            }
        }
        .refreshable {
            await vm.refreshData()
        }
    }

    @ViewBuilder
    private func propertyStatsHeader(_ vm: PropertyDetailViewModel) -> some View {
        let prop = vm.property
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(prop.occupiedPrivateRooms.count)/\(prop.privateRooms.count)")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Ocupadas")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 30)

            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", prop.occupancyRate))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(prop.occupancyRate >= 80 ? .green : .orange)
                Text("Ocupación")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 30)

            VStack(spacing: 2) {
                Text(formatCurrency(prop.monthlyRevenue))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.mint)
                Text("Renta/mes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 30)

            VStack(spacing: 2) {
                Text("\(vm.activeTenants.count)")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Inquilinos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
