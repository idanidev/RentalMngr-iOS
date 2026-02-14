import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var results: SearchResults?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            if let results, !results.isEmpty {
                if !results.properties.isEmpty {
                    Section("Propiedades") {
                        ForEach(results.properties) { property in
                            NavigationLink(value: property) {
                                VStack(alignment: .leading) {
                                    Text(property.name).font(.subheadline)
                                    Text(property.address).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !results.rooms.isEmpty {
                    Section("Habitaciones") {
                        ForEach(results.rooms) { room in
                            HStack {
                                Circle().fill(room.occupied ? .green : .orange).frame(width: 8, height: 8)
                                Text(room.name).font(.subheadline)
                                Spacer()
                                Text(formatCurrency(room.monthlyRent)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !results.tenants.isEmpty {
                    Section("Inquilinos") {
                        ForEach(results.tenants) { tenant in
                            VStack(alignment: .leading) {
                                Text(tenant.fullName).font(.subheadline)
                                if let email = tenant.email {
                                    Text(email).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else if !searchText.isEmpty && !isSearching {
                EmptyStateView(icon: "magnifyingglass", title: "Sin resultados", subtitle: "No se encontraron coincidencias para \"\(searchText)\"")
            }
        }
        .navigationTitle("Buscar")
        .searchable(text: $searchText, prompt: "Buscar propiedades, habitaciones, inquilinos...")
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            guard !newValue.isEmpty else {
                results = nil
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                isSearching = true
                results = try? await appState.searchService.search(query: newValue)
                isSearching = false
            }
        }
        .navigationDestination(for: Property.self) { property in
            PropertyDetailView(property: property)
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
