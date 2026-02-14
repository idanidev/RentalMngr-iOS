import SwiftUI

struct IncomeListView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddSheet = false
    let propertyId: UUID
    let income: [Income]

    var body: some View {
        Group {
            if income.isEmpty {
                EmptyStateView(
                    icon: "arrow.down.circle",
                    title: "Sin ingresos",
                    subtitle: "Registra los cobros de alquiler",
                    actionTitle: "Añadir ingreso"
                ) {
                    showAddSheet = true
                }
            } else {
                List {
                    ForEach(income) { item in
                        IncomeRow(item: item) {
                            Task {
                                if item.paid {
                                    try? await appState.financeService.markAsUnpaid(
                                        incomeId: item.id)
                                } else {
                                    try? await appState.financeService.markAsPaid(incomeId: item.id)
                                }
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
                IncomeFormView(propertyId: propertyId)
            }
        }
    }
}

private struct IncomeRow: View {
    let item: Income
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: item.paid ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.paid ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.roomName)
                    .font(.headline)
                if let tenantName = item.tenantName {
                    Text(tenantName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Text("Mes: \(item.month.monthYear)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formatCurrency(item.amount))
                .fontWeight(.semibold)
                .foregroundStyle(item.paid ? .green : .orange)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
