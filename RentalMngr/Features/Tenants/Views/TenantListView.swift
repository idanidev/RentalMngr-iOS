import SwiftUI
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "TenantListView")

struct TenantListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var viewModel: TenantListViewModel?
    @State private var showAddSheet = false
    @State private var showRenewalConfirmation = false
    @State private var selectedTenantForRenewal: Tenant?
    let propertyId: UUID

    var body: some View {
        Group {
            if let vm = viewModel {
                tenantContent(vm)
            } else {
                ProgressView(
                    String(localized: "Loading tenants...", locale: LanguageService.currentLocale, comment: "Loading indicator for tenants"))
            }
        }
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
            if let vm = viewModel { Task { await vm.refresh() } }
        } content: {
            NavigationStack {
                TenantFormView(propertyId: propertyId, tenant: nil)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .onAppear {
            logger.debug("onAppear fired for propertyId: \(propertyId)")
            if viewModel == nil {
                viewModel = TenantListViewModel(
                    propertyId: propertyId,
                    tenantService: appState.tenantService,
                    roomService: appState.roomService,
                    realtimeService: appState.realtimeService
                )
            }
        }
        .task {
            await viewModel?.loadTenants()
        }
    }

    @ViewBuilder
    private func tenantContent(_ vm: TenantListViewModel) -> some View {
        if vm.isLoading {
            ProgressView(
                String(localized: "Loading tenants...", locale: LanguageService.currentLocale, comment: "Loading indicator for tenants"))
        } else if let error = vm.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Error loading tenants", comment: "Error heading when tenants fail to load")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(String(localized: "Retry", locale: LanguageService.currentLocale, comment: "Retry loading button")) {
                    Task { await vm.loadTenants() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    // Filter Toggle
                    Picker(
                        "Filter",
                        selection: Binding(get: { vm.showInactive }, set: { vm.showInactive = $0 })
                    ) {
                        Text("Active", comment: "Filter for active tenants").tag(false)
                        Text("All", comment: "Filter for all tenants").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    if vm.filteredTenants.isEmpty {
                        EmptyStateView(
                            icon: "person.crop.circle",
                            title: String(localized: "No tenants",
                                locale: LanguageService.currentLocale, comment: "Empty state title when no tenants"),
                            subtitle: vm.showInactive
                                ? String(localized: "No tenants found",
                                    locale: LanguageService.currentLocale, comment: "Empty state subtitle when showing all tenants")
                                : String(localized: "No active tenants",
                                    locale: LanguageService.currentLocale, comment: "Empty state subtitle when only showing active tenants"
                                ),
                            actionTitle: String(localized: "Add Tenant", locale: LanguageService.currentLocale, comment: "Button to add a tenant")
                        ) {
                            showAddSheet = true
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.filteredTenants) { tenant in
                                NavigationLink(value: tenant) {
                                    TenantRow(tenant: tenant)
                                        .equatable()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if tenant.active {
                                        Button(role: .destructive) {
                                            Task { await vm.deactivateTenant(tenant) }
                                        } label: {
                                            Label(
                                                String(localized: "Deactivate",
                                                    locale: LanguageService.currentLocale, comment:
                                                        "Context menu action to deactivate tenant"),
                                                systemImage: "person.slash.fill"
                                            )
                                        }

                                        Button {
                                            selectedTenantForRenewal = tenant
                                            showRenewalConfirmation = true
                                        } label: {
                                            Label(
                                                String(localized: "Renew",
                                                    locale: LanguageService.currentLocale, comment:
                                                        "Context menu action to renew tenant contract"
                                                ),
                                                systemImage: "arrow.clockwise"
                                            )
                                        }

                                        if let phone = tenant.phone, !phone.isEmpty,
                                            let url = URL(string: "tel:\(phone)")
                                        {
                                            Button {
                                                openURL(url)
                                            } label: {
                                                Label(
                                                    String(localized: "Call",
                                                        locale: LanguageService.currentLocale, comment:
                                                            "Context menu action to call tenant"),
                                                    systemImage: "phone.fill"
                                                )
                                            }
                                        }
                                    } else {
                                        Button {
                                            Task { await vm.reactivateTenant(tenant) }
                                        } label: {
                                            Label(
                                                String(localized: "Reactivate",
                                                    locale: LanguageService.currentLocale, comment:
                                                        "Context menu action to reactivate tenant"),
                                                systemImage: "person.badge.shield.checkmark.fill"
                                            )
                                        }
                                    }
                                }
                                .onAppear {
                                    if tenant.id == vm.filteredTenants.last?.id {
                                        Task { await vm.loadMore() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if vm.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
            }
            .refreshable {
                await vm.refresh()
            }
            .confirmationDialog(
                String(localized: "Renew contract", locale: LanguageService.currentLocale, comment: "Renewal confirmation dialog title"),
                isPresented: $showRenewalConfirmation, titleVisibility: .visible
            ) {
                Button(String(localized: "Renew 6 months", locale: LanguageService.currentLocale, comment: "Renew contract for 6 months"))
                {
                    if let t = selectedTenantForRenewal {
                        Task { await vm.renewContract(tenant: t, months: 6) }
                    }
                }
                Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button"), role: .cancel) {}
            } message: {
                Text("Select the renewal duration", comment: "Renewal duration selection prompt")
            }
        }
    }

}

private struct TenantRow: View, Equatable {
    let tenant: Tenant

    static func == (lhs: TenantRow, rhs: TenantRow) -> Bool {
        lhs.tenant == rhs.tenant
    }

    /// Contract time progress (0...1). 1 = just started, 0 = expired
    private var contractProgress: Double {
        guard let start = tenant.contractStartDate, let end = tenant.contractEndDate else {
            return 0
        }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let remaining = end.timeIntervalSince(Date())
        let progress = 1.0 - (remaining / total)
        return max(0, min(1, progress))
    }

    /// Days remaining on the contract
    private var daysRemaining: Int {
        tenant.contractEndDate?.daysUntil ?? 0
    }

    /// Color based on contract status
    private var statusColor: Color {
        switch tenant.contractStatus {
        case .active: return .green
        case .expiringSoon: return .orange
        case .expired: return .red
        case .noContract: return .gray
        case .terminated: return .secondary
        }
    }

    /// Initials from tenant name
    private var initials: String {
        let parts = tenant.fullName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? "?"
        let last = parts.count > 1 ? (parts.last?.prefix(1) ?? "") : ""
        return "\(first)\(last)".uppercased()
    }

    /// Human-readable remaining time
    private var remainingLabel: String {
        if daysRemaining > 30 {
            let months = daysRemaining / 30
            let days = daysRemaining % 30
            if days == 0 {
                return String(localized: "\(months) month(s) remaining",
                    locale: LanguageService.currentLocale, comment: "Months remaining on contract")
            }
            return String(localized: "\(months) month(s) and \(days) day(s)",
                locale: LanguageService.currentLocale, comment: "Months and days remaining on contract")
        } else if daysRemaining > 0 {
            return String(localized: "\(daysRemaining) day(s) remaining",
                locale: LanguageService.currentLocale, comment: "Days remaining on contract")
        } else if daysRemaining == 0 {
            return String(localized: "Ends today!", locale: LanguageService.currentLocale, comment: "Contract ends today")
        } else {
            return String(localized: "Expired \(abs(daysRemaining)) days ago",
                locale: LanguageService.currentLocale, comment: "Contract expired days ago")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: Avatar + Name + Rent
            HStack(spacing: 12) {
                // Avatar with status ring
                ZStack {
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: contractProgress)
                        .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(initials)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(tenant.fullName)
                            .font(.headline)
                        if !tenant.active {
                            Text("Inactive", comment: "Inactive tenant badge")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red.opacity(0.15), in: Capsule())
                                .foregroundStyle(.red)
                        }
                    }

                    // Room badge
                    if let room = tenant.room {
                        HStack(spacing: 4) {
                            Image(systemName: "bed.double.fill")
                                .font(.caption2)
                            Text(room.name)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                    }
                }

                Spacer()

                // Rent amount
                if let rent = tenant.effectiveMonthlyRent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(rent.formatted(currencyCode: "EUR"))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text("/mo", comment: "Per month abbreviation for rent")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Contract section
            if let startDate = tenant.contractStartDate, let endDate = tenant.contractEndDate {
                VStack(spacing: 6) {
                    // Contract date range
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(startDate.dayMonthYear)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text("\(endDate.dayMonthYear)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(statusColor)
                        Spacer()
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(statusColor.opacity(0.15))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(statusColor)
                                .frame(width: max(0, geo.size.width * contractProgress), height: 6)
                        }
                    }
                    .frame(height: 6)

                    // Status label
                    HStack {
                        Text(tenant.contractStatus.label)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor)

                        Spacer()

                        Text(remainingLabel)
                            .font(.caption2)
                            .fontWeight(daysRemaining <= 0 ? .bold : .regular)
                            .foregroundStyle(daysRemaining <= 0 ? .red : .secondary)
                    }
                }
            } else {
                // No contract
                HStack(spacing: 4) {
                    Image(systemName: "doc.questionmark")
                        .font(.caption2)
                    Text("No contract defined", comment: "Label when tenant has no contract")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

            }

            // Contact info row
            if let phone = tenant.phone, !phone.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.caption2)
                    Text(phone)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

}
