import SwiftUI

struct ExpenseListView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddSheet = false
    let propertyId: UUID
    let expenses: [Expense]

    var body: some View {
        Group {
            if expenses.isEmpty {
                EmptyStateView(
                    icon: "arrow.up.circle",
                    title: "Sin gastos",
                    subtitle: "Registra los gastos de esta propiedad",
                    actionTitle: "Añadir gasto"
                ) {
                    showAddSheet = true
                }
            } else {
                List {
                    ForEach(groupedByCategory.sorted(by: { $0.key < $1.key }), id: \.key) {
                        category, items in
                        Section(category) {
                            ForEach(items) { expense in
                                ExpenseRow(expense: expense)
                            }
                        }
                    }
                }
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
            NavigationStack {
                ExpenseFormView(propertyId: propertyId, expense: nil)
            }
        }
    }

    private var groupedByCategory: [String: [Expense]] {
        Dictionary(grouping: expenses, by: \.category)
    }
}

private struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description ?? expense.category)
                    .font(.subheadline)

                // Location info
                Group {
                    if let roomName = expense.room?.name {
                        Label(roomName, systemImage: "bed.double")
                    } else if let propertyName = expense.property?.name {
                        Label(propertyName, systemImage: "building.2")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Text(expense.date.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatCurrency(expense.amount))
                .fontWeight(.semibold)
                .foregroundStyle(.red)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
