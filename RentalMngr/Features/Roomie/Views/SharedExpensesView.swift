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
        .navigationTitle(String(localized: "Shared expenses", locale: LanguageService.currentLocale, comment: "Navigation title for shared expenses list"))
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
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
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
            EmptyStateView(icon: "person.2.circle", title: String(localized: "No shared expenses", locale: LanguageService.currentLocale, comment: "Empty state title"), subtitle: String(localized: "Track expenses to split among tenants", locale: LanguageService.currentLocale, comment: "Empty state subtitle for shared expenses"),
                           actionTitle: String(localized: "Add expense", locale: LanguageService.currentLocale, comment: "Button to add shared expense")) { showAddSheet = true }
        } else {
            List {
                ForEach(vm.sharedExpenses) { expense in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.title).font(.subheadline).fontWeight(.semibold)
                            HStack(spacing: 8) {
                                Text(expense.category.displayName)
                                    .font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.secondary.opacity(0.2), in: Capsule())
                                Text(expense.date.shortFormatted).font(.caption).foregroundStyle(.secondary)
                                Text("·  \(expense.splitType.displayName)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(expense.amount.formatted(currencyCode: "EUR")).fontWeight(.semibold)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await vm.deleteExpense(expense) }
                        } label: { Label(String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Swipe action to delete"), systemImage: "trash") }
                    }
                }
            }
            .refreshable {
                await vm.loadExpenses()
            }
        }
    }

}
