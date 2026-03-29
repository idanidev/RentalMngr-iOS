import SwiftUI

struct IncomeListView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddSheet = false
    @State private var errorMessage: String?
    let propertyId: UUID
    let income: [Income]
    var onLoadMore: (() async -> Void)? = nil
    var onRefresh: (() async -> Void)? = nil
    var onAdded: (() async -> Void)? = nil

    var body: some View {
        Group {
            if income.isEmpty {
                EmptyStateView(
                    icon: "arrow.down.circle",
                    title: String(localized: "No income", locale: LanguageService.currentLocale, comment: "Empty state title when no income recorded"
                    ),
                    subtitle: String(localized: "Record your rental payments",
                        locale: LanguageService.currentLocale, comment: "Empty state subtitle for income list"),
                    actionTitle: String(localized: "Add income", locale: LanguageService.currentLocale, comment: "Button to add new income entry")
                ) {
                    showAddSheet = true
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(income) { item in
                        VStack(spacing: 0) {
                            IncomeRow(item: item) {
                                Task {
                                    do {
                                        if item.paid {
                                            try await appState.financeService.markAsUnpaid(
                                                incomeId: item.id)
                                        } else {
                                            try await appState.financeService.markAsPaid(
                                                incomeId: item.id)
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            Divider().padding(.leading, 16)
                        }
                        .background(Color(.systemBackground))
                        .onAppear {
                            if item.id == income.last?.id {
                                if let onLoadMore {
                                    Task { await onLoadMore() }
                                }
                            }
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
            NavigationStack {
                IncomeFormView(propertyId: propertyId)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .alert(String(localized: "Error", locale: LanguageService.currentLocale, comment: "Alert title"), isPresented: .constant(errorMessage != nil)) {
            Button(String(localized: "OK", locale: LanguageService.currentLocale, comment: "Alert dismiss button")) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

private struct IncomeRow: View {
    let item: Income
    let onToggle: () async -> Void

    var body: some View {
        HStack {
            Button {
                Task { await onToggle() }
            } label: {
                Image(systemName: item.paid ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.paid ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if let tenantName = item.tenantName {
                    Text("\(tenantName) (\(item.roomName))")
                        .font(.headline)
                } else {
                    Text(item.roomName)
                        .font(.headline)
                }
                Text(String(localized: "Month: \(item.month.monthYear)", locale: LanguageService.currentLocale, comment: "Income row month label"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(item.amount.formatted(currencyCode: "EUR"))
                .fontWeight(.semibold)
                .foregroundStyle(item.paid ? .green : .orange)
        }
    }
}
