import SwiftUI

struct ExpenseFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ExpenseViewModel?

    let propertyId: UUID
    let expense: Expense?

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(String(localized: expense == nil ? "New expense" : "Edit expense", locale: LanguageService.currentLocale, comment: "Navigation title for expense form"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Button to cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save", locale: LanguageService.currentLocale, comment: "Button to save")) {
                    Task {
                        if let _ = await viewModel?.save() { dismiss() }
                    }
                }
                .disabled(viewModel?.isFormValid != true)
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            guard let userId = appState.authService.currentUserId else {
                dismiss()   // Should never happen — user must be authenticated to reach this view
                return
            }
            viewModel = ExpenseViewModel(
                propertyId: propertyId,
                financeService: appState.financeService,
                userId: userId,
                expense: expense
            )
        }
    }

    @ViewBuilder
    private func formContent(_ vm: ExpenseViewModel) -> some View {
        Form {
            Section {
                TextField(String(localized: "Amount (€)", locale: LanguageService.currentLocale, comment: "Amount field placeholder for expense"), text: Binding(get: { vm.amount }, set: { vm.amount = $0 }))
                    .keyboardType(.decimalPad)

                Picker(String(localized: "Category", locale: LanguageService.currentLocale, comment: "Expense form"), selection: Binding(get: { vm.category }, set: { vm.category = $0 })) {
                    ForEach(ExpenseCategory.allCases) { cat in
                        Text(cat.displayName).tag(cat.rawValue)
                    }
                }

                DatePicker(String(localized: "Date", locale: LanguageService.currentLocale, comment: "Date picker label"), selection: Binding(get: { vm.date }, set: { vm.date = $0 }), displayedComponents: .date)

                TextField(String(localized: "Description (optional)", locale: LanguageService.currentLocale, comment: "Description field placeholder"), text: Binding(get: { vm.description }, set: { vm.description = $0 }), axis: .vertical)
                    .lineLimit(2...4)
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
    }
}
