import SwiftUI

struct PropertyListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var viewModel: PropertyListViewModel?
    @State private var showAddSheet = false
    @State private var showPaywall = false
    @State private var pendingAction: DestructiveAction?

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
                    // Free tier: max 1 property. Show paywall when limit reached.
                    let count = viewModel?.properties.count ?? 0
                    if !appState.entitlementService.isPremium && count >= FreeTierLimits.maxProperties {
                        showPaywall = true
                    } else {
                        showAddSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Añadir propiedad", locale: LanguageService.currentLocale, comment: "Accessibility label for add property button"))
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(highlightedFeature: .unlimitedProperties)
                .environment(appState.entitlementService)
        }
        .sheet(isPresented: $showAddSheet) {
            // Force a full reload on dismiss: loadProperties() is a no-op once
            // isLoaded is true, so a freshly created property would never appear.
            if let vm = viewModel {
                Task { await vm.refresh() }
            }
        } content: {
            NavigationStack {
                PropertyFormView(property: nil)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .destructiveConfirmation($pendingAction)
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

    /// Borrar una propiedad cascadea a trece tablas: habitaciones, inquilinos,
    /// ingresos, gastos, documentos... El diálogo del sistema deja el detalle en
    /// gris diminuto y resume con un "Delete" que no dice qué borra; esta hoja
    /// lo cuenta con los números reales antes de tocar nada.
    private func deleteConfirmation(for property: Property, vm: PropertyListViewModel) -> DestructiveAction {
        let propertyId = property.id
        return DestructiveAction(
            title: String(localized: "¿Borrar \(property.name)?", locale: LanguageService.currentLocale, comment: "Delete property title"),
            message: String(localized: "Se borrará la propiedad entera y todo lo que cuelga de ella. Esto no se puede deshacer.", locale: LanguageService.currentLocale, comment: "Delete property message"),
            confirmLabel: String(localized: "Borrar propiedad", locale: LanguageService.currentLocale, comment: "Confirm delete property"),
            icon: "building.2.fill",
            impact: { await DeletionImpactService.forProperty(propertyId) },
            perform: { await vm.deleteProperty(property) }
        )
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
                    Task { await vm.refresh() }
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
        } else if hSize == .regular {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 360), spacing: 16, alignment: .top)],
                    spacing: 16
                ) {
                    ForEach(vm.properties) { property in
                        NavigationLink(value: property) {
                            PropertyRichCard(property: property)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingAction = deleteConfirmation(for: property, vm: vm)
                            } label: {
                                Label(
                                    String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Swipe action to delete property"),
                                    systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await vm.refresh()
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
                            pendingAction = deleteConfirmation(for: property, vm: vm)
                        } label: {
                            Label(
                                String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Swipe action to delete property"),
                                systemImage: "trash")
                        }
                    }
                }
            }
            .refreshable {
                await vm.refresh()
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
