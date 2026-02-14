import SwiftUI

struct IncomeFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: IncomeViewModel?
    @State private var rooms: [Room] = []

    let propertyId: UUID

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Nuevo ingreso")
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
            if viewModel == nil {
                viewModel = IncomeViewModel(
                    propertyId: propertyId,
                    financeService: appState.financeService
                )
            }
        }
        .task {
            rooms = (try? await appState.roomService.fetchRooms(propertyId: propertyId)) ?? []
        }
    }

    @ViewBuilder
    private func formContent(_ vm: IncomeViewModel) -> some View {
        Form {
            Section {
                Picker("Habitación", selection: Binding(get: { vm.roomId }, set: { vm.roomId = $0 })) {
                    Text("Seleccionar...").tag(nil as UUID?)
                    ForEach(rooms.filter { $0.roomType == .privateRoom }) { room in
                        Text(room.name).tag(room.id as UUID?)
                    }
                }

                TextField("Importe (€)", text: Binding(get: { vm.amount }, set: { vm.amount = $0 }))
                    .keyboardType(.decimalPad)

                DatePicker("Mes", selection: Binding(get: { vm.month }, set: { vm.month = $0 }), displayedComponents: .date)
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
    }
}
