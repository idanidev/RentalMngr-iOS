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
        .navigationTitle(String(localized: "Properties", locale: LanguageService.currentLocale, comment: "Property list navigation title"))
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
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .confirmationDialog(
            String(localized: "Delete property?",
                locale: LanguageService.currentLocale, comment: "Confirmation dialog title for deleting a property"),
            isPresented: Binding(
                get: { propertyToDelete != nil },
                set: { if !$0 { propertyToDelete = nil } }
            )
        ) {
            Button(
                String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Delete property button"), role: .destructive
            ) {
                if let property = propertyToDelete {
                    Task { await viewModel?.deleteProperty(property) }
                }
            }
        } message: {
            Text(
                String(
                    localized: "This action cannot be undone. All associated rooms, tenants, and financial data will be deleted.",
                    locale: LanguageService.currentLocale,
                    comment: "Delete property warning message"
                )
            )
        }
        .navigationDestination(for: Property.self) { property in
            PropertyDetailView(property: property)
        }
        .navigationDestination(for: Tenant.self) { tenant in
            TenantDetailView(tenant: tenant)
        }
        .navigationDestination(for: Room.self) { room in
            RoomDetailView(room: room)
        }
        .task {
            if viewModel == nil {
                viewModel = PropertyListViewModel(
                    propertyService: appState.propertyService,
                    realtimeService: appState.realtimeService
                )
            }
            await viewModel?.loadProperties()
        }
    }

    @ViewBuilder
    private func propertyList(_ vm: PropertyListViewModel) -> some View {
        if let error = vm.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(
                    "Error loading properties",
                    comment: "Error heading when properties fail to load"
                )
                .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(String(localized: "Retry", locale: LanguageService.currentLocale, comment: "Retry loading button")) {
                    Task { await vm.loadProperties() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else if vm.properties.isEmpty && !vm.isLoading {
            EmptyStateView(
                icon: "building.2",
                title: String(localized: "No properties",
                    locale: LanguageService.currentLocale, comment: "Empty state title when no properties exist"),
                subtitle: String(localized: "Add your first property to get started",
                    locale: LanguageService.currentLocale, comment: "Empty state subtitle for properties"),
                actionTitle: String(localized: "Add Property", locale: LanguageService.currentLocale, comment: "Button to add first property")
            ) {
                showAddSheet = true
            }
        } else {
            List {
                ForEach(vm.properties) { property in
                    NavigationLink(value: property) {
                        PropertyRow(property: property)
                            .equatable()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            propertyToDelete = property
                        } label: {
                            Label(
                                String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Swipe action to delete property"),
                                systemImage: "trash")
                        }
                    }
                }
            }
            .refreshable {
                await vm.loadProperties()
            }
        }
    }
}

private struct PropertyRow: View, Equatable {
    let property: Property

    static func == (lhs: PropertyRow, rhs: PropertyRow) -> Bool {
        lhs.property == rhs.property
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.indigo.opacity(0.15), .purple.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(property.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(property.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    let occupied = property.occupiedPrivateRooms.count
                    let total = property.privateRooms.count
                    if total > 0 {
                        Label("\(occupied)/\(total) hab.", systemImage: "bed.double.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if property.monthlyRevenue > 0 {
                        Text(property.monthlyRevenue.formatted(currencyCode: "EUR"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.mint)
                    }
                }
            }

            Spacer(minLength: 0)

            if property.privateRooms.count > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", property.occupancyRate))
                        .font(.caption.bold())
                        .foregroundStyle(property.occupancyRate >= 80 ? .green : .orange)
                    Text("ocupación")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
