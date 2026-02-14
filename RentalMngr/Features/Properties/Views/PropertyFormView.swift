import SwiftUI

struct PropertyFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PropertyFormViewModel?

    let property: Property?

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(property == nil ? "Nueva propiedad" : "Editar propiedad")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    Task {
                        if let _ = await viewModel?.save() {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel?.isFormValid != true || viewModel?.isLoading == true)
            }
        }
        .onAppear {
            if viewModel == nil {
                if let userId = appState.authService.currentUserId {
                    viewModel = PropertyFormViewModel(
                        propertyService: appState.propertyService,
                        userId: userId,
                        property: property
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func formContent(_ vm: PropertyFormViewModel) -> some View {
        Form {
            Section("Información") {
                TextField("Nombre", text: Binding(get: { vm.name }, set: { vm.name = $0 }))
                TextField("Dirección", text: Binding(get: { vm.address }, set: { vm.address = $0 }))
                TextField("Descripción (opcional)", text: Binding(get: { vm.description }, set: { vm.description = $0 }), axis: .vertical)
                    .lineLimit(3...6)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .loadingOverlay(vm.isLoading)
    }
}
