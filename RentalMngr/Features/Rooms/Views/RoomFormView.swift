import SwiftUI
import PhotosUI

struct RoomFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RoomFormViewModel?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []

    let propertyId: UUID
    let room: Room?

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(room == nil ? "Nueva habitación" : "Editar habitación")
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
                viewModel = RoomFormViewModel(
                    propertyId: propertyId,
                    roomService: appState.roomService,
                    room: room
                )
            }
        }
    }

    @ViewBuilder
    private func formContent(_ vm: RoomFormViewModel) -> some View {
        Form {
            Section("Información") {
                TextField("Nombre", text: Binding(get: { vm.name }, set: { vm.name = $0 }))

                TextField("Renta mensual (€)", text: Binding(get: { vm.monthlyRent }, set: { vm.monthlyRent = $0 }))
                    .keyboardType(.decimalPad)

                TextField("Tamaño m² (opcional)", text: Binding(get: { vm.sizeSqm }, set: { vm.sizeSqm = $0 }))
                    .keyboardType(.decimalPad)

                Picker("Tipo", selection: Binding(get: { vm.roomType }, set: { vm.roomType = $0 })) {
                    Text("Privada").tag(RoomType.privateRoom)
                    Text("Común").tag(RoomType.common)
                }
            }

            Section("Fotos") {
                PhotoPickerView(selectedItems: $selectedPhotos, images: $photoData, maxCount: 10)
            }

            Section("Notas") {
                TextField("Notas (opcional)", text: Binding(get: { vm.notes }, set: { vm.notes = $0 }), axis: .vertical)
                    .lineLimit(3...6)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .loadingOverlay(vm.isLoading)
    }
}
