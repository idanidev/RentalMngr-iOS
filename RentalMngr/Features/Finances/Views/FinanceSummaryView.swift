import SwiftUI

struct FinanceSummaryView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: FinanceSummaryViewModel?
    @State private var showAddExpense = false
    @State private var showAddIncome = false

    let propertyId: UUID

    var body: some View {
        Group {
            if let vm = viewModel {
                financeContent(vm)
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = FinanceSummaryViewModel(
                    propertyId: propertyId,
                    financeService: appState.financeService
                )
            }
            await viewModel?.loadData()
        }
    }

    @ViewBuilder
    private func financeContent(_ vm: FinanceSummaryViewModel) -> some View {
        VStack(spacing: 0) {
            // Date filter toggle + month picker
            dateFilterBar(vm)

            Picker(
                "Sección",
                selection: Binding(get: { vm.selectedSection }, set: { vm.selectedSection = $0 })
            ) {
                ForEach(FinanceSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch vm.selectedSection {
            case .summary:
                summaryContent(vm)
            case .expenses:
                ExpenseListView(propertyId: propertyId, expenses: vm.expenses)
            case .income:
                IncomeListView(propertyId: propertyId, income: vm.income)
            }
        }
    }

    @ViewBuilder
    private func dateFilterBar(_ vm: FinanceSummaryViewModel) -> some View {
        VStack(spacing: 8) {
            HStack {
                Toggle(
                    isOn: Binding(
                        get: { vm.filterByDate },
                        set: { newValue in
                            vm.filterByDate = newValue
                            Task { await vm.loadData() }
                        }
                    )
                ) {
                    Label("Filtrar por mes", systemImage: "calendar")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if vm.filterByDate {
                DatePicker(
                    "Mes",
                    selection: Binding(
                        get: { vm.selectedDate },
                        set: { newDate in
                            vm.selectedDate = newDate
                            Task { await vm.loadData() }
                        }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .padding(.horizontal)

                Text(monthYearLabel(vm.selectedDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func summaryContent(_ vm: FinanceSummaryViewModel) -> some View {
        ScrollView {
            if let summary = vm.summary {
                VStack(spacing: 12) {
                    // Key stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12)
                    {
                        StatCard(
                            title: "Ingresos", value: formatCurrency(summary.totalIncome),
                            icon: "arrow.down.circle.fill", color: .green)
                        StatCard(
                            title: "Gastos", value: formatCurrency(summary.totalExpenses),
                            icon: "arrow.up.circle.fill", color: .red)
                        StatCard(
                            title: "Beneficio neto", value: formatCurrency(summary.netProfit),
                            icon: "eurosign.circle.fill",
                            color: summary.netProfit >= 0 ? .mint : .red)
                        StatCard(
                            title: "Pagos",
                            value:
                                "\(summary.paidCount) pagados / \(summary.unpaidCount) pendientes",
                            icon: "checkmark.circle.fill", color: .blue)
                    }

                    // Expenses by category breakdown
                    if !vm.expensesByCategory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gastos por categoría")
                                .font(.headline)
                                .padding(.top, 8)

                            ForEach(vm.expensesByCategory, id: \.category) { item in
                                HStack {
                                    Image(systemName: iconForCategory(item.category))
                                        .foregroundStyle(colorForCategory(item.category))
                                        .frame(width: 24)
                                    Text(item.category.capitalized)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(formatCurrency(item.amount))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.red)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Profit margin
                    if summary.totalIncome > 0 {
                        HStack {
                            Image(systemName: "chart.pie.fill")
                                .foregroundStyle(.blue)
                            Text("Margen de beneficio")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f%%", summary.profitMargin))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(summary.profitMargin >= 0 ? .green : .red)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            } else {
                EmptyStateView(
                    icon: "chart.bar", title: "Sin datos",
                    subtitle: "Añade ingresos y gastos para ver el resumen")
            }
        }
    }

    private func monthYearLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date).capitalized
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "agua": return "drop.fill"
        case "luz", "electricidad": return "bolt.fill"
        case "gas": return "flame.fill"
        case "internet", "wifi": return "wifi"
        case "mantenimiento", "reparación": return "wrench.fill"
        case "limpieza": return "sparkles"
        case "seguro": return "shield.fill"
        case "impuestos": return "doc.text.fill"
        case "comunidad": return "building.2.fill"
        default: return "eurosign.circle"
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "agua": return .blue
        case "luz", "electricidad": return .yellow
        case "gas": return .orange
        case "internet", "wifi": return .purple
        case "mantenimiento", "reparación": return .brown
        case "limpieza": return .mint
        case "seguro": return .green
        case "impuestos": return .red
        case "comunidad": return .cyan
        default: return .gray
        }
    }
}
