import SwiftUI

struct PropertyDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var currentProperty: Property
    @State private var viewModel: PropertyDetailViewModel?
    @State private var showEditSheet = false
    @State private var showSharingSheet = false
    @State private var showContractPreview = false
    // Section tab lives in the View (not the VM) so it survives VM recreation /
    // realtime refreshes — editing a room or contract no longer resets it to Rooms.
    @State private var selectedTab: PropertyTab = .rooms

    init(property: Property) {
        _currentProperty = State(initialValue: property)
    }

    /// La propiedad se alquila entera: cambia cómo se nombra la sección de
    /// habitaciones, que ahí son partes de una misma vivienda.
    private var isSingleUnit: Bool {
        viewModel?.property.isSingleUnit ?? currentProperty.isSingleUnit
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                detailContent(vm)
            } else {
                loadingSkeleton
            }
        }
        .navigationTitle(viewModel?.property.name ?? currentProperty.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                actionsMenu
            }
        }
        .errorAlert(Binding(
            get: { viewModel?.errorMessage },
            set: { viewModel?.errorMessage = $0 }))
        .sheet(isPresented: $showEditSheet) {
            if let vm = viewModel { Task { await vm.refreshData() } }
        } content: {
            NavigationStack {
                PropertyFormView(property: viewModel?.property ?? currentProperty)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showSharingSheet) {
            NavigationStack {
                PropertySharingView(property: currentProperty)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showContractPreview) {
            NavigationStack {
                ContractPreviewView(property: viewModel?.property ?? currentProperty)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .onAppear { appState.selectedProperty = currentProperty }
        .onDisappear {
            if appState.selectedProperty?.id == currentProperty.id {
                appState.selectedProperty = nil
            }
        }
        .task(id: currentProperty.id) {
            // Only rebuild the VM when the property actually changed. A bare
            // re-appearance (returning from a pushed room, a realtime-driven
            // refresh, etc.) keeps the existing VM and the selected tab.
            if viewModel?.property.id != currentProperty.id {
                viewModel = nil
                selectedTab = .rooms
                let vm = PropertyDetailViewModel(
                    property: currentProperty,
                    currentUserId: appState.authService.currentUserId,
                    propertyService: appState.propertyService,
                    roomService: appState.roomService,
                    tenantService: appState.tenantService,
                    realtimeService: appState.realtimeService
                )
                viewModel = vm
                await vm.loadData()
            } else {
                await viewModel?.refreshData()
            }
        }
    }

    // MARK: - Toolbar: Actions Menu

    private var actionsMenu: some View {
        Menu {
            Button {
                showEditSheet = true
            } label: {
                Label(
                    String(localized: "Edit", locale: LanguageService.currentLocale, comment: "Edit property"),
                    systemImage: "pencil"
                )
            }
            Button {
                showSharingSheet = true
            } label: {
                Label(
                    String(localized: "Share", locale: LanguageService.currentLocale, comment: "Share property"),
                    systemImage: "person.badge.plus"
                )
            }

            Button {
                showContractPreview = true
            } label: {
                Label(
                    String(localized: "Vista previa del contrato", locale: LanguageService.currentLocale, comment: "Preview contract PDF action"),
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(String(localized: "Más opciones", locale: LanguageService.currentLocale, comment: "Accessibility label for actions menu button"))
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(_ vm: PropertyDetailViewModel) -> some View {
        ZStack(alignment: .bottom) {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    propertyHeroHeader(vm)

                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .rooms:
                            RoomListView(propertyId: currentProperty.id, rooms: vm.rooms)
                        case .tenants:
                            TenantListView(propertyId: currentProperty.id)
                        case .finances:
                            FinanceSummaryView(propertyId: currentProperty.id)
                        case .documents:
                            DocumentListView(appState: appState, propertyId: currentProperty.id)
                        case .contract:
                            PropertyContractView(
                                propertyId: currentProperty.id,
                                property: Binding(
                                    get: { vm.property },
                                    set: { vm.property = $0 }
                                ),
                                canEdit: vm.canEdit
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { await vm.refreshData() }

            // Floating section bar
            floatingTabBar()
        }
    }

    // MARK: - Hero Header

    private func propertyHeroHeader(_ vm: PropertyDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Address + Revenue
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.property.address)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)

                    if vm.property.monthlyRevenue > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(vm.property.monthlyRevenue.formatted(currencyCode: "EUR"))
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            Text("/ mes")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                Spacer()
            }

            // Stats Row
            HStack(spacing: 0) {
                heroStat(
                    value: "\(vm.occupiedRooms)/\(vm.privateRooms.count)",
                    label: "Habitaciones",
                    icon: "bed.double.fill",
                    color: .white
                )
                Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 30)
                heroStat(
                    value: String(format: "%.0f%%", vm.occupancyRate * 100),
                    label: "Ocupación",
                    icon: "chart.pie.fill",
                    color: vm.occupancyRate >= 0.8 ? .green : (vm.occupancyRate >= 0.5 ? .orange : .red)
                )
                Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 30)
                heroStat(
                    value: "\(vm.tenants.count)",
                    label: "Inquilinos",
                    icon: "person.2.fill",
                    color: .white
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.45, blue: 0.05), Color(red: 0.98, green: 0.62, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func heroStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.subheadline)
                Text(value).font(.system(.title3, design: .rounded, weight: .bold))
            }
            .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Floating Tab Bar

    private func floatingTabBar() -> some View {
        HStack(spacing: 0) {
            ForEach(PropertyTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon(isSingleUnit: isSingleUnit))
                            .font(.system(size: 18, weight: selectedTab == tab ? .bold : .medium))
                            .symbolEffect(.bounce, value: selectedTab == tab)
                        Text(tab.displayName(isSingleUnit: isSingleUnit))
                            .font(.caption2)
                            .fontWeight(selectedTab == tab ? .bold : .regular)
                            .opacity(selectedTab == tab ? 1.0 : 0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? Color.orange : .secondary)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .frame(maxWidth: hSize == .regular ? .infinity : 520)
        .padding(.horizontal, hSize == .regular ? 20 : 24)
        .padding(.bottom, 8)
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: 0) {
            SkeletonView()
                .frame(height: 130)
            VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonView().frame(height: 80)
                }
            }
            .padding()
            Spacer()
        }
    }
}
