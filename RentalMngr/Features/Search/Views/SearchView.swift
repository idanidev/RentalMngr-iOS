import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var results: SearchResults?
    @State private var isSearching = false

    var body: some View {
        List {
            if let results, !results.isEmpty {
                if !results.properties.isEmpty {
                    Section(String(localized: "Properties", locale: LanguageService.currentLocale, comment: "Search results section for properties")) {
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
                    Section(String(localized: "Rooms", locale: LanguageService.currentLocale, comment: "Search results section for rooms")) {
                        ForEach(results.rooms) { room in
                            HStack {
                                Circle().fill(room.occupied ? .green : .orange).frame(width: 8, height: 8)
                                Text(room.name).font(.subheadline)
                                Spacer()
                                Text(room.monthlyRent.formatted(currencyCode: "EUR")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !results.tenants.isEmpty {
                    Section(String(localized: "Tenants", locale: LanguageService.currentLocale, comment: "Search results section for tenants")) {
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
                EmptyStateView(icon: "magnifyingglass", title: String(localized: "No results", locale: LanguageService.currentLocale, comment: "Empty state title for search"), subtitle: String(localized: "No matches found for \"\(searchText)\"", locale: LanguageService.currentLocale, comment: "Empty state subtitle for search"))
            }
        }
        .navigationTitle(String(localized: "Search", locale: LanguageService.currentLocale, comment: "Navigation title for search view"))
        .searchable(text: $searchText, prompt: Text("Search properties, rooms, tenants...", comment: "Search bar placeholder"))
        .task(id: searchText) {
            guard !searchText.isEmpty else {
                results = nil
                isSearching = false
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            isSearching = true
            results = try? await appState.searchService.search(query: searchText)
            isSearching = false
        }
        .navigationDestination(for: Property.self) { property in
            PropertyDetailView(property: property)
        }
    }

}
