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
        .navigationTitle(expense == nil ? "Nuevo gasto" : "Editar gasto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    Task {
                        if let _ = await viewModel?.save() { dismiss() }
                    }
                }
                .disabled(viewModel?.isFormValid != true)
            }
        }
        .onAppear {
            if viewModel == nil, let userId = appState.authService.currentUserId {
                viewModel = ExpenseViewModel(
                    propertyId: propertyId,
                    financeService: appState.financeService,
                    userId: userId,
                    expense: expense
                )
            }
        }
    }

    @ViewBuilder
    private func formContent(_ vm: ExpenseViewModel) -> some View {
        Form {
            Section {
                TextField("Importe (€)", text: Binding(get: { vm.amount }, set: { vm.amount = $0 }))
                    .keyboardType(.decimalPad)

                Picker("Categoría", selection: Binding(get: { vm.category }, set: { vm.category = $0 })) {
                    ForEach(ExpenseViewModel.categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }

                DatePicker("Fecha", selection: Binding(get: { vm.date }, set: { vm.date = $0 }), displayedComponents: .date)

                TextField("Descripción (opcional)", text: Binding(get: { vm.description }, set: { vm.description = $0 }), axis: .vertical)
                    .lineLimit(2...4)
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
    }
}
