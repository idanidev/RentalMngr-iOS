import SwiftUI

struct HouseRuleFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var category: HouseRuleCategory = .comunidad
    @State private var isLoading = false
    @State private var errorMessage: String?

    let propertyId: UUID

    var body: some View {
        Form {
            Section {
                TextField("Título *", text: $title)
                Picker("Categoría", selection: $category) {
                    ForEach(HouseRuleCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue.capitalized).tag(cat)
                    }
                }
                TextField("Descripción", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle("Nueva norma")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
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
