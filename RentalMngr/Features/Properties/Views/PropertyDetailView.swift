import SwiftUI

struct PropertyDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var currentProperty: Property
    @State private var viewModel: PropertyDetailViewModel?
    @State private var allProperties: [Property] = []
    @State private var showEditSheet = false
    @State private var showSharingSheet = false

    init(property: Property) {
        _currentProperty = State(initialValue: property)
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                detailContent(vm)
            } else {
                loadingSkeleton
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                propertySwitcherButton
            }
            ToolbarItem(placement: .primaryAction) {
                actionsMenu
            }
        }
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
        .onAppear { appState.selectedProperty = currentProperty }
        .onDisappear {
            if appState.selectedProperty?.id == currentProperty.id {
                appState.selectedProperty = nil
            }
        }
        .task(id: currentProperty.id) {
            viewModel = nil
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

            if allProperties.isEmpty {
                allProperties = (try? await appState.propertyService.fetchProperties()) ?? []
            }
        }
    }

    // MARK: - Toolbar: Property Switcher

    private var propertySwitcherButton: some View {
        Menu {
            ForEach(allProperties) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentProperty = p
                        appState.selectedProperty = p
                    }
                } label: {
                    Label(p.name, systemImage: p.id == currentProperty.id ? "checkmark" : "building.2")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentProperty.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(allProperties.count > 1 ? 1 : 0)
            }
            .frame(maxWidth: 220)
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
        } label: {
            Image(systemName: "ellipsis.circle")
        }
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
                        switch vm.selectedTab {
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
                    .padding(.bottom, 100)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { await vm.refreshData() }

            // Floating Tab Bar
            floatingTabBar(vm)
        }
    }

    // MARK: - Hero Header

    private func propertyHeroHeader(_ vm: PropertyDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Address + Revenue
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.property.address)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)

                    if vm.property.monthlyRevenue > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(vm.property.monthlyRevenue.formatted(currencyCode: "EUR"))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("/ mes")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
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
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [.orange.opacity(0.85), .orange.opacity(0.3), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func heroStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2)
                Text(value).font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Floating Tab Bar

    private func floatingTabBar(_ vm: PropertyDetailViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(PropertyTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        vm.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: vm.selectedTab == tab ? .bold : .medium))
                            .symbolEffect(.bounce, value: vm.selectedTab == tab)
                        Text(tab.displayName)
                            .font(.caption2)
                            .fontWeight(vm.selectedTab == tab ? .bold : .regular)
                            .opacity(vm.selectedTab == tab ? 1.0 : 0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(vm.selectedTab == tab ? Color.orange : Color.gray.opacity(0.8))
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
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
