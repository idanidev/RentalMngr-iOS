import SwiftUI

struct GlobalFinanceView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: GlobalFinanceViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                financeContent(vm)
            } else {
                ProgressView("Cargando finanzas...")
            }
        }
        .navigationTitle("Finanzas")
        .task {
            if viewModel == nil {
                viewModel = GlobalFinanceViewModel(
                    propertyService: appState.propertyService,
                    financeService: appState.financeService
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
                    Button("Reintentar") { Task { await vm.loadData() } }
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
                                title: "Sin propiedades",
                                subtitle: "No tienes propiedades registradas"
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
    }

    // MARK: - Month Selector

    private func monthSelector(_ vm: GlobalFinanceViewModel) -> some View {
        HStack {
            Button {
                vm.changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(vm.monthYearLabel)
                .font(.headline)

            Spacer()

            Button {
                vm.changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Summary Cards

    private func summaryCards(_ vm: GlobalFinanceViewModel) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            SummaryCard(
                title: "Esperado",
                amount: vm.totalExpected,
                color: .blue
            )
            SummaryCard(
                title: "Cobrado",
                amount: vm.totalPaid,
                color: .green
            )
            SummaryCard(
                title: "Pendiente",
                amount: vm.totalPending,
                color: vm.totalPending > 0 ? .red : .green
            )
        }
    }

    // MARK: - Property Section

    private func propertySection(_ property: Property, vm: GlobalFinanceViewModel) -> some View {
        let income = vm.incomeForProperty(property.id)

        return VStack(alignment: .leading, spacing: 8) {
            // Property header
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.blue)
                Text(property.name)
                    .font(.headline)
                Spacer()

                if !income.isEmpty {
                    let paid = income.filter(\.paid).count
                    let total = income.count
                    Text("\(paid)/\(total)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(paid == total ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (paid == total ? Color.green : Color.orange).opacity(0.15)
                        )
                        .clipShape(Capsule())
                }
            }

            // Income rows or empty state
            if income.isEmpty {
                HStack {
                    Image(systemName: "eurosign.circle")
                        .foregroundStyle(.secondary)
                    Text("Sin ingresos registrados para este mes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(income, id: \.id) { income in
                    IncomePaymentRow(income: income) {
                        // Toggle paid/unpaid
                        Task {
                            if income.paid {
                                await vm.markAsUnpaid(income)
                            } else {
                                await vm.markAsPaid(income)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let amount: Decimal
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatCurrency(amount))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}

// MARK: - Income Payment Row

private struct IncomePaymentRow: View {
    let income: Income
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Button(action: onToggle) {
                Image(systemName: income.paid ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(income.paid ? .green : .red)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(income.room?.name ?? "Habitación")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let tenantName = income.tenantName {
                    Text(tenantName)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                if income.paid, let date = income.paymentDate {
                    Text("Pagado \(date.shortFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formatCurrency(income.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(income.paid ? .green : .primary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(income.paid ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
