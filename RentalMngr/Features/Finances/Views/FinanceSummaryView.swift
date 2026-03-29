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
        .toolbar {
            if let vm = viewModel, vm.selectedSection == .expenses || vm.selectedSection == .income {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if viewModel?.selectedSection == .expenses {
                            showAddExpense = true
                        } else {
                            showAddIncome = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddExpense) {
            if let vm = viewModel { Task { await vm.refresh() } }
        } content: {
            NavigationStack {
                ExpenseFormView(propertyId: propertyId, expense: nil)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showAddIncome) {
            if let vm = viewModel { Task { await vm.refresh() } }
        } content: {
            NavigationStack {
                IncomeFormView(propertyId: propertyId)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .task {
            if viewModel == nil {
                viewModel = FinanceSummaryViewModel(
                    propertyId: propertyId,
                    financeService: appState.financeService,
                    utilityService: appState.utilityService,
                    realtimeService: appState.realtimeService
                )
            }
            await viewModel?.loadData()
        }
    }

    @ViewBuilder
    private func financeContent(_ vm: FinanceSummaryViewModel) -> some View {
        VStack(spacing: 24) {
            // Date filter & Section Picker Container
            VStack(spacing: 16) {
                dateFilterBar(vm)

                // Custom Segmented Control
                HStack(spacing: 0) {
                    ForEach(FinanceSection.allCases, id: \.self) { section in
                        Button {
                            withAnimation { vm.selectedSection = section }
                        } label: {
                            Text(section.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    vm.selectedSection == section ? Color.white : Color.clear
                                )
                                .foregroundStyle(
                                    vm.selectedSection == section ? .black : .white
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top, 16)

            switch vm.selectedSection {
            case .summary:
                ScrollView {
                    summaryContent(vm)
                }
                .refreshable {
                    await vm.refresh()
                }
            case .expenses:
                ExpenseListView(
                    propertyId: propertyId, expenses: vm.expenses,
                    onLoadMore: { await vm.loadMore() },
                    onRefresh: { await vm.refresh() },
                    onAdded: { await vm.refresh() }
                )
            case .income:
                IncomeListView(
                    propertyId: propertyId, income: vm.income,
                    onLoadMore: { await vm.loadMore() },
                    onRefresh: { await vm.refresh() },
                    onAdded: { await vm.refresh() }
                )
            case .utilities:
                UtilityChargesView(
                    vm: vm,
                    onLoadMore: { await vm.loadMore() })
            }

        }
        .padding(.bottom, 20)
        .overlay {
            if let error = vm.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button(String(localized: "Retry", locale: LanguageService.currentLocale, comment: "Button to retry loading")) {
                        Task { await vm.loadData() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
        }
    }

    @ViewBuilder
    private func dateFilterBar(_ vm: FinanceSummaryViewModel) -> some View {
        HStack {
            Button {
                withAnimation {
                    vm.filterByDate.toggle()
                    Task { await vm.refresh() }
                }
            } label: {
                HStack {
                    Image(systemName: vm.filterByDate ? "calendar.badge.clock" : "calendar")
                    Text(
                        vm.filterByDate
                            ? String(localized: "Filtering by month",
                                locale: LanguageService.currentLocale, comment: "Filter label when monthly filter is active")
                            : String(localized: "All time",
                                locale: LanguageService.currentLocale, comment: "Filter label when showing all time data"))
                }
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(vm.filterByDate ? .blue : .gray.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }

            Spacer()

            if vm.filterByDate {
                HStack {
                    Text(monthYearLabel(vm.selectedDate))
                        .font(.headline)
                        .foregroundStyle(.white)

                    // Invisible date picker overlay
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { vm.selectedDate },
                            set: { newDate in
                                vm.selectedDate = newDate
                                Task { await vm.refresh() }
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                    .colorInvert()
                    .brightness(1)
                    .frame(width: 80)  // Adjust touch target
                    .opacity(0.011)  // Almost invisible but functional
                    .overlay(alignment: .trailing) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func summaryContent(_ vm: FinanceSummaryViewModel) -> some View {
        if let summary = vm.summary {
            VStack(spacing: 20) {
                // Profit margin (Featured)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profit margin", comment: "Label for profit margin percentage")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", summary.profitMargin))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(summary.profitMargin >= 0 ? .green : .red)
                    }
                    Spacer()

                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(.gray.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(abs(summary.profitMargin) / 100, 1.0))
                            .stroke(
                                summary.profitMargin >= 0 ? .green : .red,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 60, height: 60)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )

                // Key stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    FinanceStatCard(
                        title: String(localized: "Income", locale: LanguageService.currentLocale, comment: "Finance stat card title for income"),
                        value: summary.totalIncome.formatted(currencyCode: "EUR"),
                        icon: "arrow.down.left",
                        color: .green,
                        gradient: [.green.opacity(0.6), .green.opacity(0.3)]
                    )
                    FinanceStatCard(
                        title: String(localized: "Expenses", locale: LanguageService.currentLocale, comment: "Finance stat card title for expenses"),
                        value: summary.totalExpenses.formatted(currencyCode: "EUR"),
                        icon: "arrow.up.right",
                        color: .red,
                        gradient: [.red.opacity(0.6), .red.opacity(0.3)]
                    )
                    FinanceStatCard(
                        title: String(localized: "Profit", locale: LanguageService.currentLocale, comment: "Finance stat card title for net profit"),
                        value: summary.netProfit.formatted(currencyCode: "EUR"),
                        icon: "eurosign",
                        color: summary.netProfit >= 0 ? .mint : .pink,
                        gradient: summary.netProfit >= 0
                            ? [.mint.opacity(0.6), .cyan.opacity(0.3)]
                            : [.pink.opacity(0.6), .red.opacity(0.3)]
                    )

                    // Payments Stats
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checklist")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(summary.paidCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Paid", comment: "Label for paid count")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Divider().background(.white.opacity(0.2))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(summary.unpaidCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                            Text("Pending", comment: "Label for pending/unpaid count")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                // Expenses by category breakdown
                if !vm.expensesByCategory.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(
                            "Expense Breakdown",
                            comment: "Section header for expense breakdown by category"
                        )
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.leading, 4)

                        VStack(spacing: 8) {
                            ForEach(vm.expensesByCategory, id: \.category) { item in
                                HStack {
                                    Circle()
                                        .fill(colorForCategory(item.category).opacity(0.2))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: iconForCategory(item.category))
                                                .font(.caption)
                                                .foregroundStyle(colorForCategory(item.category))
                                        )

                                    Text(ExpenseCategory.displayName(for: item.category))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)

                                    Spacer()

                                    Text(item.amount.formatted(currencyCode: "EUR"))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        } else {
            EmptyStateView(
                icon: "chart.bar",
                title: String(localized: "No data", locale: LanguageService.currentLocale, comment: "Empty state title for finance summary"),
                subtitle: String(localized: "Add income and expenses to see the summary",
                    locale: LanguageService.currentLocale, comment: "Empty state subtitle for finance summary"))
        }
    }

    private func monthYearLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year()).capitalized
    }

    private func iconForCategory(_ category: String) -> String {
        ExpenseCategory.icon(for: category)
    }

    private func colorForCategory(_ category: String) -> Color {
        ExpenseCategory.color(for: category)
    }
}

private struct FinanceStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var gradient: [Color] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())

                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                if !gradient.isEmpty {
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ).opacity(0.3)
                } else {
                    color.opacity(0.1)
                }
            }
        )
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
