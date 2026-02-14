import SwiftUI

struct PropertyListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: PropertyListViewModel?
    @State private var showAddSheet = false
    @State private var propertyToDelete: Property?

    var body: some View {
        Group {
            if let vm = viewModel {
                propertyList(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Propiedades")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let vm = viewModel {
                Task { await vm.loadProperties() }
            }
        } content: {
            NavigationStack {
                PropertyFormView(property: nil)
            }
        }
        .confirmationDialog(
            "¿Eliminar propiedad?",
            isPresented: Binding(
                get: { propertyToDelete != nil },
                set: { if !$0 { propertyToDelete = nil } }
            )
        ) {
            Button("Eliminar", role: .destructive) {
                if let property = propertyToDelete {
                    Task { await viewModel?.deleteProperty(property) }
                }
            }
        } message: {
            Text(
                "Esta acción no se puede deshacer. Se eliminarán todas las habitaciones, inquilinos y datos financieros asociados."
            )
        }
        .task {
            if viewModel == nil {
                viewModel = PropertyListViewModel(propertyService: appState.propertyService)
            }
            await viewModel?.loadProperties()
        }
    }

    @ViewBuilder
    private func propertyList(_ vm: PropertyListViewModel) -> some View {
        if vm.properties.isEmpty && !vm.isLoading {
            EmptyStateView(
                icon: "building.2",
                title: "Sin propiedades",
                subtitle: "Añade tu primera propiedad para empezar",
                actionTitle: "Añadir propiedad"
            ) {
                showAddSheet = true
            }
        } else {
            List {
                ForEach(vm.properties) { property in
                    NavigationLink(value: property) {
                        PropertyRow(property: property)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            propertyToDelete = property
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationDestination(for: Property.self) { property in
                PropertyDetailView(property: property)
            }
            .refreshable {
                await vm.loadProperties()
            }
        }
    }
}

private struct PropertyRow: View {
    let property: Property

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(property.name)
                .font(.headline)
            Text(property.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Room stats from embedded rooms
            HStack(spacing: 12) {
                // Rooms count
                Label("\(property.privateRooms.count) hab.", systemImage: "bed.double")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Occupancy
                let occupied = property.occupiedPrivateRooms.count
                let total = property.privateRooms.count
                if total > 0 {
                    Label("\(occupied)/\(total) ocupadas", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(occupied == total ? .green : .orange)
                }

                // Revenue
                if property.monthlyRevenue > 0 {
                    Text(formatCurrency(property.monthlyRevenue))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.mint)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
