import SwiftUI

struct SharedExpensesView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: SharedExpensesViewModel?
    @State private var showAddSheet = false
    let propertyId: UUID

    var body: some View {
        Group {
            if let vm = viewModel {
                expenseContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Gastos compartidos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let vm = viewModel { Task { await vm.loadExpenses() } }
        } content: {
            NavigationStack {
                SharedExpenseFormView(propertyId: propertyId)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SharedExpensesViewModel(propertyId: propertyId, sharedExpenseService: appState.sharedExpenseService)
            }
        }
        .task {
            await viewModel?.loadExpenses()
        }
    }

    @ViewBuilder
    private func expenseContent(_ vm: SharedExpensesViewModel) -> some View {
        if vm.sharedExpenses.isEmpty {
            EmptyStateView(icon: "person.2.circle", title: "Sin gastos compartidos", subtitle: "Registra gastos para dividir entre inquilinos",
                           actionTitle: "Añadir gasto") { showAddSheet = true }
        } else {
            List {
                ForEach(vm.sharedExpenses) { expense in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.title).font(.subheadline).fontWeight(.semibold)
                            HStack(spacing: 8) {
                                Text(expense.category.rawValue.capitalized)
                                    .font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.secondary.opacity(0.2), in: Capsule())
                                Text(expense.date.shortFormatted).font(.caption).foregroundStyle(.secondary)
                                Text("·  \(expense.splitType.rawValue)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(formatCurrency(expense.amount)).fontWeight(.semibold)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await vm.deleteExpense(expense) }
                        } label: { Label("Eliminar", systemImage: "trash") }
                    }
                }
            }
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
