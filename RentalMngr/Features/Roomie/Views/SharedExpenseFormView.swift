import SwiftUI

struct SharedExpenseFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var amount = ""
    @State private var category: SharedExpenseCategory = .utilities
    @State private var date = Date()
    @State private var splitType: SplitType = .equal
    @State private var isLoading = false
    @State private var errorMessage: String?

    let propertyId: UUID

    var body: some View {
        Form {
            Section(String(localized: "Details", locale: LanguageService.currentLocale, comment: "Section header for shared expense details")) {
                TextField(String(localized: "Title *", locale: LanguageService.currentLocale, comment: "Placeholder for shared expense title field"), text: $title)
                TextField(String(localized: "Amount (€) *", locale: LanguageService.currentLocale, comment: "Placeholder for shared expense amount field"), text: $amount).keyboardType(.decimalPad)
                Picker(String(localized: "Category", locale: LanguageService.currentLocale, comment: "Label for shared expense category picker"), selection: $category) {
                    ForEach(SharedExpenseCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
                DatePicker(String(localized: "Date", locale: LanguageService.currentLocale, comment: "Date picker label for shared expense"), selection: $date, displayedComponents: .date)
                Picker(String(localized: "Split type", locale: LanguageService.currentLocale, comment: "Picker label for expense split type"), selection: $splitType) {
                    ForEach(SplitType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField(String(localized: "Description", locale: LanguageService.currentLocale, comment: "Placeholder for shared expense description"), text: $description, axis: .vertical).lineLimit(2...4)
            }
            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle(String(localized: "New shared expense", locale: LanguageService.currentLocale, comment: "Navigation title for new shared expense form"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save", locale: LanguageService.currentLocale, comment: "Save button")) {
                    Task {
                        guard let userId = appState.authService.currentUserId,
                              let decimalAmount = Decimal(string: amount) else { return }
                        isLoading = true
                        do {
                            _ = try await appState.sharedExpenseService.createSharedExpense(
                                propertyId: propertyId, title: title,
                                description: description.isEmpty ? nil : description,
                                amount: decimalAmount, category: category, date: date,
                                splitType: splitType, createdBy: userId
                            )
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isLoading = false
                    }
                }
                .disabled(title.isEmpty || amount.isEmpty || isLoading)
            }
        }
    }
}
