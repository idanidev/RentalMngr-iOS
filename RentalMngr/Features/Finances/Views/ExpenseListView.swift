import SwiftUI

struct ExpenseListView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddSheet = false
    @State private var expenseToEdit: Expense? = nil
    @State private var expenseToDelete: Expense? = nil
    let propertyId: UUID
    let expenses: [Expense]
    var onLoadMore: (() async -> Void)? = nil
    var onRefresh: (() async -> Void)? = nil
    var onAdded: (() async -> Void)? = nil

    var body: some View {
        Group {
            if expenses.isEmpty {
                EmptyStateView(
                    icon: "arrow.up.circle",
                    title: String(localized: "No expenses", locale: LanguageService.currentLocale, comment: "Empty state title when no expenses"),
                    subtitle: String(localized: "Record expenses for this property",
                        locale: LanguageService.currentLocale, comment: "Empty state subtitle for expenses"),
                    actionTitle: String(localized: "Add expense", locale: LanguageService.currentLocale, comment: "Button to add a new expense")
                ) {
                    showAddSheet = true
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(groupedByCategory.sorted(by: { $0.key < $1.key }), id: \.key) { category, items in
                        Section {
                            ForEach(items) { expense in
                                VStack(spacing: 0) {
                                    ExpenseRow(expense: expense)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                        .contextMenu {
                                            Button {
                                                expenseToEdit = expense
                                            } label: {
                                                Label(String(localized: "Edit", locale: LanguageService.currentLocale, comment: "Edit expense"), systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                expenseToDelete = expense
                                            } label: {
                                                Label(String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Delete expense"), systemImage: "trash")
                                            }
                                        }
                                    Divider().padding(.leading, 16)
                                }
                                .background(Color(.systemBackground))
                                .onAppear {
                                    if expense.id == expenses.last?.id {
                                        if let onLoadMore { Task { await onLoadMore() } }
                                    }
                                }
                            }
                        } header: {
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGroupedBackground))
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let onAdded { Task { await onAdded() } }
        } content: {
            NavigationStack { ExpenseFormView(propertyId: propertyId, expense: nil) }
                .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(item: $expenseToEdit, onDismiss: {
            if let onRefresh { Task { await onRefresh() } }
        }) { expense in
            NavigationStack { ExpenseFormView(propertyId: propertyId, expense: expense) }
                .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .confirmationDialog(
            String(localized: "Delete expense?", locale: LanguageService.currentLocale, comment: "Delete expense confirmation title"),
            isPresented: Binding(get: { expenseToDelete != nil }, set: { if !$0 { expenseToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Delete expense button"), role: .destructive) {
                if let expense = expenseToDelete {
                    Task {
                        try? await appState.financeService.deleteExpense(id: expense.id)
                        expenseToDelete = nil
                        if let onRefresh { await onRefresh() }
                    }
                }
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
                Text(expense.description ?? ExpenseCategory.displayName(for: expense.category))
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
            Text(expense.amount.formatted(currencyCode: "EUR"))
                .fontWeight(.semibold)
                .foregroundStyle(.red)
        }
    }
}
