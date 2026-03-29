import SwiftUI

struct GlobalFinanceView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: GlobalFinanceViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                financeContent(vm)
            } else {
                ProgressView(
                    String(localized: "Loading finances...", locale: LanguageService.currentLocale, comment: "Loading message for finances"))
            }
        }
        .navigationTitle(
            String(localized: "Finances", locale: LanguageService.currentLocale, comment: "Navigation title for finances view")
        )
        .task {
            if viewModel == nil {
                viewModel = GlobalFinanceViewModel(
                    propertyService: appState.propertyService,
                    financeService: appState.financeService,
                    utilityService: appState.utilityService,
                    realtimeService: appState.realtimeService
                )
            }
            await viewModel?.loadData()
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func financeContent(_ vm: GlobalFinanceViewModel) -> some View {
        VStack(spacing: 0) {
            // Month selector
            monthSelector(vm)

            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = vm.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(String(localized: "Retry", locale: LanguageService.currentLocale, comment: "Button to retry loading")) {
                        Task { await vm.loadData() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Summary cards
                        summaryCards(vm)

                        // Properties
                        if vm.properties.isEmpty {
                            EmptyStateView(
                                icon: "building.2",
                                title: String(localized: "No properties",
                                    locale: LanguageService.currentLocale, comment: "Empty state title when no properties exist"),
                                subtitle: String(localized: "You have no registered properties",
                                    locale: LanguageService.currentLocale, comment: "Empty state subtitle for no properties")
                            )
                            .padding(.top, 40)
                        } else {
                            ForEach(vm.propertiesWithIncome) { property in
                                propertySection(property, vm: vm)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .refreshable {
            await vm.refresh()
        }
    }

    // MARK: - Month Selector

    private func monthSelector(_ vm: GlobalFinanceViewModel) -> some View {
        HStack(spacing: 0) {
            Button { vm.changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            Spacer()
            Text(vm.monthYearLabel)
                .font(.headline)
            Spacer()
            Button { vm.changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Summary Cards

    private func summaryCards(_ vm: GlobalFinanceViewModel) -> some View {
        HStack(spacing: 12) {
            FinanceSummaryCard(
                title: "Esperado",
                amount: vm.totalExpected,
                icon: "calendar.circle.fill",
                color: .indigo
            )
            FinanceSummaryCard(
                title: "Cobrado",
                amount: vm.totalPaid,
                icon: "checkmark.circle.fill",
                color: .green
            )
            FinanceSummaryCard(
                title: "Pendiente",
                amount: vm.totalPending,
                icon: "clock.circle.fill",
                color: vm.totalPending > 0 ? .red : .green
            )
        }
    }

    // MARK: - Property Section

    private func propertySection(_ property: Property, vm: GlobalFinanceViewModel) -> some View {
        let roomGroups = vm.paymentsByPropertyAndRoom[property.id] ?? []
        let totalItems = roomGroups.reduce(0) { $0 + $1.totalItems }
        let paidItems = roomGroups.reduce(0) { $0 + $1.paidItems }

        return VStack(alignment: .leading, spacing: 8) {
            // Property header
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.blue)
                Text(property.name)
                    .font(.headline)
                Spacer()

                if totalItems > 0 {
                    Text("\(paidItems)/\(totalItems)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(paidItems == totalItems ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (paidItems == totalItems ? Color.green : Color.orange).opacity(0.15)
                        )
                        .clipShape(Capsule())
                }
            }

            // Room payment groups
            if roomGroups.isEmpty {
                HStack {
                    Image(systemName: "eurosign.circle")
                        .foregroundStyle(.secondary)
                    Text("Sin ingresos registrados este mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(roomGroups) { group in
                    roomPaymentSection(group, vm: vm)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Room Payment Section (Rent + Utilities)

    private func roomPaymentSection(_ group: RoomPaymentGroup, vm: GlobalFinanceViewModel)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            // Tenant/Room header
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let tenant = group.tenantName {
                    Text(tenant)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text(group.roomName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()

                // Paid count badge
                Text("\(group.paidItems)/\(group.totalItems)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(group.allPaid ? .green : .orange)
            }
            .padding(.bottom, 2)

            // Rent row
            if let rent = group.rent {
                IncomePaymentRow(income: rent) {
                    Task {
                        if rent.paid {
                            await vm.markAsUnpaid(rent)
                        } else {
                            await vm.markAsPaid(rent)
                        }
                    }
                }
            }

            // Utility rows
            ForEach(group.utilities) { charge in
                UtilityPaymentRow(charge: charge) {
                    Task {
                        if charge.paid {
                            await vm.markUtilityUnpaid(charge)
                        } else {
                            await vm.markUtilityPaid(charge)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Finance Summary Card

private struct FinanceSummaryCard: View {
    let title: String
    let amount: Decimal
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(amount.formatted(currencyCode: "EUR"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }
}

// MARK: - Income Payment Row

private struct IncomePaymentRow: View {
    let income: Income
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: income.paid ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(income.paid ? .green : .red)
            }
            .buttonStyle(.plain)

            Image(systemName: "house.fill")
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Alquiler")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if income.paid, let date = income.paymentDate {
                    Text("Pagado el \(date.shortFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(income.amount.formatted(currencyCode: "EUR"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(income.paid ? .green : .primary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(income.paid ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Utility Payment Row

private struct UtilityPaymentRow: View {
    let charge: UtilityCharge
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: charge.paid ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(charge.paid ? .green : .red)
            }
            .buttonStyle(.plain)

            if let type = charge.type {
                Image(systemName: type.icon)
                    .font(.caption)
                    .foregroundStyle(type.color)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(charge.type?.displayName ?? charge.utilityType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if charge.paid, let date = charge.paymentDate {
                    Text("Pagado el \(date.shortFormatted)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if charge.amount > 0 {
                Text(charge.amount.formatted(currencyCode: "EUR"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(charge.paid ? .green : .primary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(charge.paid ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
