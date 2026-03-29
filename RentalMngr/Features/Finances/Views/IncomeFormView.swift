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
        .navigationTitle(String(localized: "New income", locale: LanguageService.currentLocale, comment: "Navigation title for new income form"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save", locale: LanguageService.currentLocale, comment: "Save button")) {
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
                Picker(String(localized: "Room", locale: LanguageService.currentLocale, comment: "Room picker label"), selection: Binding(get: { vm.roomId }, set: { vm.roomId = $0 })) {
                    Text("Select...", comment: "Picker placeholder").tag(nil as UUID?)
                    ForEach(rooms.filter { $0.roomType == .privateRoom }) { room in
                        Text(room.name).tag(room.id as UUID?)
                    }
                }

                TextField(String(localized: "Amount (€)", locale: LanguageService.currentLocale, comment: "Amount placeholder for income form"), text: Binding(get: { vm.amount }, set: { vm.amount = $0 }))
                    .keyboardType(.decimalPad)

                DatePicker(String(localized: "Month", locale: LanguageService.currentLocale, comment: "Month date picker label"), selection: Binding(get: { vm.month }, set: { vm.month = $0 }), displayedComponents: .date)
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
    }
}
