import SwiftUI

struct SharedExpenseFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var amount = ""
    @State private var category: SharedExpenseCategory = .servicios
    @State private var date = Date()
    @State private var splitType: SplitType = .equal
    @State private var isLoading = false
    @State private var errorMessage: String?

    let propertyId: UUID

    var body: some View {
        Form {
            Section("Detalle") {
                TextField("Título *", text: $title)
                TextField("Importe (€) *", text: $amount).keyboardType(.decimalPad)
                Picker("Categoría", selection: $category) {
                    ForEach(SharedExpenseCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue.capitalized).tag(cat)
                    }
                }
                DatePicker("Fecha", selection: $date, displayedComponents: .date)
                Picker("División", selection: $splitType) {
                    Text("Partes iguales").tag(SplitType.equal)
                    Text("Personalizado").tag(SplitType.custom)
                    Text("Por habitación").tag(SplitType.byRoom)
                }
                TextField("Descripción", text: $description, axis: .vertical).lineLimit(2...4)
            }
            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle("Nuevo gasto compartido")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
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
