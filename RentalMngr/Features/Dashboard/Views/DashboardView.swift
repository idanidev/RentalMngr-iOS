import SwiftUI

private enum QuickActionTarget { case tenant, expense, income }

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: DashboardViewModel?
    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var showAddProperty = false
    @State private var showAddTenant = false
    @State private var showAddExpense = false
    @State private var showAddIncome = false
    @State private var selectedPropertyId: UUID?
    @State private var pendingQuickAction: QuickActionTarget?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let vm = viewModel {
                    if vm.isLoading && vm.properties.isEmpty {
                        loadingSkeleton
                    } else {
                        heroCard(vm)
                        quickActionsSection
                        if !vm.properties.isEmpty {
                            propertiesSection(vm)
                        }
                        if !vm.expiringContracts.isEmpty {
                            alertsSection(vm)
                        }
                    }
                } else {
                    loadingSkeleton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("RentalMngr")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                avatarButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                bellButton(vm: viewModel)
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showNotifications) {
            NavigationStack { NotificationListView() }
                .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showAddProperty) {
            NavigationStack { PropertyFormView(property: nil) }
                .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
                .onDisappear {
                    Task { await viewModel?.refresh() }
                }
        }
        .sheet(isPresented: $showAddTenant) {
            if let propId = selectedPropertyId {
                NavigationStack { TenantFormView(propertyId: propId, tenant: nil) }
                    .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
            }
        }
        .sheet(isPresented: $showAddExpense) {
            if let propId = selectedPropertyId {
                NavigationStack { ExpenseFormView(propertyId: propId, expense: nil) }
                    .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
            }
        }
        .sheet(isPresented: $showAddIncome) {
            if let propId = selectedPropertyId {
                NavigationStack { IncomeFormView(propertyId: propId) }
                    .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
            }
        }
        .sheet(isPresented: Binding(get: { pendingQuickAction != nil }, set: { if !$0 { pendingQuickAction = nil } })) {
            PropertyPickerSheet(
                properties: viewModel?.properties ?? [],
                action: pendingQuickAction
            ) { property, action in
                selectedPropertyId = property.id
                pendingQuickAction = nil
                switch action {
                case .tenant:  showAddTenant = true
                case .expense: showAddExpense = true
                case .income:  showAddIncome = true
                }
            } onCancel: {
                pendingQuickAction = nil
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .refreshable {
            await viewModel?.refresh()
        }
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

    // MARK: - Toolbar

    private var avatarButton: some View {
        Button { showSettings = true } label: {
            let initial = appState.authService.currentUserEmail?.prefix(1).uppercased() ?? "?"
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(initial)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ajustes")
    }

    @ViewBuilder
    private func bellButton(vm: DashboardViewModel?) -> some View {
        let alertCount = (vm?.pendingPayments ?? 0) + (vm?.expiringContracts.count ?? 0)
        Button { showNotifications = true } label: {
            Image(systemName: alertCount > 0 ? "bell.badge.fill" : "bell.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(alertCount > 0 ? .orange : .primary)
        }
        .accessibilityLabel("Notificaciones")
    }

    // MARK: - Greeting helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<13: return "Buenos días"
        case 13..<21: return "Buenas tardes"
        default:      return "Buenas noches"
        }
    }

    private var firstName: String {
        guard let email = appState.authService.currentUserEmail else { return "" }
        let localPart = email.components(separatedBy: "@").first ?? ""
        return localPart.components(separatedBy: ".").first?.capitalized ?? localPart.capitalized
    }

    private var formattedDate: String {
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
    }

    // MARK: - Hero Card

    @ViewBuilder
    private func heroCard(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text(firstName.isEmpty ? greeting : "\(greeting), \(firstName)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Ingresos del mes")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(vm.totalMonthlyIncome, format: .currency(code: "EUR"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if vm.pendingPayments > 0 {
                        Text("\(vm.pendingPayments) pendientes")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.2), in: Capsule())
                        .foregroundStyle(.white)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Ocupación")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Text(String(format: "%.0f%%", vm.occupancyRate))
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule()
                            .fill(.white)
                            .frame(width: geo.size.width * min(CGFloat(vm.occupancyRate / 100), 1))
                            .animation(.spring(duration: 0.8), value: vm.occupancyRate)
                    }
                }
                .frame(height: 6)
            }

            HStack(spacing: 0) {
                heroStat(value: "\(vm.properties.count)", label: "Propiedades")
                heroDivider
                heroStat(value: "\(vm.occupiedRooms)/\(vm.totalRooms)", label: "Habitaciones")
                heroDivider
                heroStat(value: vm.collectedIncome.formatted(currencyCode: "EUR"), label: "Cobrado")
            }
            .padding(.top, 4)
        }
        .padding(22)
        .background {
            LinearGradient(
                colors: [.orange, Color(red: 0.9, green: 0.4, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(.rect(cornerRadius: 22))
        .shadow(color: .orange.opacity(0.4), radius: 18, y: 8)
    }

    @ViewBuilder
    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.25))
            .frame(width: 1, height: 28)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Acciones rápidas")
                .font(.headline)

            HStack(spacing: 0) {
                QuickActionButton(icon: "building.2.fill", label: "Propiedad", color: .indigo) {
                    showAddProperty = true
                }
                QuickActionButton(icon: "person.badge.plus", label: "Inquilino", color: .green) {
                    triggerQuickAction(.tenant)
                }
                QuickActionButton(icon: "eurosign.circle.fill", label: "Cobrar", color: .mint) {
                    triggerQuickAction(.income)
                }
                QuickActionButton(icon: "minus.circle.fill", label: "Gasto", color: .orange) {
                    triggerQuickAction(.expense)
                }
                QuickActionButton(icon: "bell.fill", label: "Alertas", color: .pink) {
                    showNotifications = true
                }
            }
        }
    }

    private func triggerQuickAction(_ action: QuickActionTarget) {
        guard let properties = viewModel?.properties, !properties.isEmpty else { return }
        if properties.count == 1 {
            selectedPropertyId = properties[0].id
            switch action {
            case .tenant:  showAddTenant = true
            case .expense: showAddExpense = true
            case .income:  showAddIncome = true
            }
        } else {
            pendingQuickAction = action
        }
    }

    // MARK: - Properties Section

    @ViewBuilder
    private func propertiesSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Mis propiedades")
                    .font(.headline)
                Spacer()
                Button {
                    appState.selectedTab = .properties
                } label: {
                    Text("Ver todas")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
            }

            ForEach(vm.properties) { property in
                PropertyDashboardCard(property: property) {
                    appState.propertiesNavigationPath = NavigationPath([property])
                    appState.selectedTab = .properties
                }
            }
        }
    }

    // MARK: - Alerts Section

    @ViewBuilder
    private func alertsSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Contratos por vencer", systemImage: "exclamationmark.triangle.fill")
            .font(.headline)
            .foregroundStyle(.orange)

            ForEach(vm.expiringContracts) { tenant in
                ExpiringContractRow(tenant: tenant)
            }
        }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: 24) {
            SkeletonView()
                .frame(height: 190)
                .clipShape(.rect(cornerRadius: 22))

            VStack(alignment: .leading, spacing: 14) {
                SkeletonView().frame(width: 140, height: 20).clipShape(.rect(cornerRadius: 6))
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                }
            }

            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonView().frame(height: 80).clipShape(.rect(cornerRadius: 16))
                }
            }
        }
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 21))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Property Dashboard Card

private struct PropertyDashboardCard: View {
    let property: Property
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [.indigo.opacity(0.15), .purple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 52, height: 52)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 20))
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
                            Label("\(occupied)/\(total)", systemImage: "bed.double.fill")
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

                VStack(alignment: .trailing, spacing: 6) {
                    if property.privateRooms.count > 0 {
                        Text(String(format: "%.0f%%", property.occupancyRate))
                            .font(.caption.bold())
                            .foregroundStyle(property.occupancyRate >= 80 ? .green : .orange)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expiring Contract Row

private struct ExpiringContractRow: View {
    let tenant: Tenant

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tenant.fullName)
                    .font(.subheadline.weight(.semibold))
                if let endDate = tenant.contractEndDate {
                    Text("Vence \(endDate.shortFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let endDate = tenant.contractEndDate {
                Text("\(endDate.daysUntil)d")
                    .font(.caption.bold())
                    .foregroundStyle(endDate.daysUntil <= 7 ? .red : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (endDate.daysUntil <= 7 ? Color.red : Color.orange).opacity(0.1),
                        in: Capsule()
                    )
            }
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Property Picker Sheet

private struct PropertyPickerSheet: View {
    let properties: [Property]
    let action: QuickActionTarget?
    let onSelect: (Property, QuickActionTarget) -> Void
    let onCancel: () -> Void

    private var actionTitle: String {
        switch action {
        case .tenant:  return "Añadir inquilino"
        case .expense: return "Añadir gasto"
        case .income:  return "Registrar cobro"
        case nil:      return ""
        }
    }

    private var actionIcon: String {
        switch action {
        case .tenant:  return "person.badge.plus"
        case .expense: return "minus.circle.fill"
        case .income:  return "eurosign.circle.fill"
        case nil:      return ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: actionIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                Text(actionTitle)
                    .font(.title3.bold())
                Text("Selecciona una propiedad")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Property list
            VStack(spacing: 10) {
                ForEach(properties) { property in
                    Button {
                        if let action {
                            onSelect(property, action)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(
                                        colors: [.orange.opacity(0.15), .orange.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.orange)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(property.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(property.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
