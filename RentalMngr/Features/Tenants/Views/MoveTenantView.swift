import SwiftUI

struct MoveTenantView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MoveTenantViewModel

    // Callback to refresh parent view
    var onMoveSuccess: () -> Void

    init(
        tenant: Tenant,
        propertyId: UUID,
        roomService: RoomServiceProtocol,
        tenantService: TenantServiceProtocol,
        onMoveSuccess: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: MoveTenantViewModel(
                tenant: tenant,
                propertyId: propertyId,
                roomService: roomService,
                tenantService: tenantService
            )
        )
        self.onMoveSuccess = onMoveSuccess
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section(String(localized: "Select new room", locale: LanguageService.currentLocale, comment: "Section header for room selection when moving tenant")) {
                    if viewModel.availableRooms.isEmpty {
                        Text("No vacant rooms available in this property.", comment: "Message when no rooms are available for moving")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(String(localized: "Room", locale: LanguageService.currentLocale, comment: "Room picker label"), selection: $viewModel.selectedRoomId) {
                            Text("Select...", comment: "Picker placeholder").tag(UUID?.none)
                            ForEach(viewModel.availableRooms) { room in
                                Text(room.name).tag(Optional(room.id))
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                Section {
                    Button(action: {
                        Task {
                            if await viewModel.moveTenant() {
                                onMoveSuccess()
                                dismiss()
                            }
                        }
                    }) {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Move Tenant", comment: "Button to confirm moving tenant to new room")
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .navigationTitle(String(localized: "Move Tenant", locale: LanguageService.currentLocale, comment: "Navigation title for move tenant view"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button")) { dismiss() }
                }
            }
            .task {
                await viewModel.loadRooms()
            }
        }
        .presentationDetents([.medium])
    }
}
