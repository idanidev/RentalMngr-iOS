import SwiftUI

struct HouseRuleFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var category: HouseRuleCategory = .community
    @State private var isLoading = false
    @State private var errorMessage: String?

    let propertyId: UUID

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Title *", locale: LanguageService.currentLocale, comment: "Placeholder for house rule title field"), text: $title)
                Picker(String(localized: "Category", locale: LanguageService.currentLocale, comment: "Label for house rule category picker"), selection: $category) {
                    ForEach(HouseRuleCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
                TextField(String(localized: "Description", locale: LanguageService.currentLocale, comment: "Placeholder for house rule description field"), text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle(String(localized: "New rule", locale: LanguageService.currentLocale, comment: "Navigation title for new house rule form"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Button to cancel house rule creation")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save", locale: LanguageService.currentLocale, comment: "Button to save new house rule")) {
                    Task {
                        guard let userId = appState.authService.currentUserId else { return }
                        isLoading = true
                        do {
                            _ = try await appState.houseRuleService.createRule(
                                propertyId: propertyId, category: category,
                                title: title, description: description.isEmpty ? nil : description,
                                createdBy: userId
                            )
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isLoading = false
                    }
                }
                .disabled(title.isEmpty || isLoading)
            }
        }
    }
}
