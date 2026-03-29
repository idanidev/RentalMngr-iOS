import SwiftUI

struct TenantAssignView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let tenant: Tenant
    let propertyId: UUID

    @State private var rooms: [Room] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if vacantRooms.isEmpty {
                EmptyStateView(
                    icon: "bed.double.fill",
                    title: String(localized: "No rooms available", locale: LanguageService.currentLocale, comment: "Empty state title when all rooms are occupied"),
                    subtitle: String(localized: "All rooms are occupied", locale: LanguageService.currentLocale, comment: "Empty state subtitle when no rooms available for assignment")
                )
            } else {
                List(vacantRooms) { room in
                    Button {
                        Task {
                            do {
                                try await appState.tenantService.assignToRoom(tenantId: tenant.id, roomId: room.id)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(room.name)
                                .font(.headline)
                            Text(room.monthlyRent.formatted(currencyCode: "EUR") + "/mes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Assign to \(tenant.fullName)", locale: LanguageService.currentLocale, comment: "Navigation title for assigning tenant to a room"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button")) { dismiss() }
            }
        }
        .errorAlert($errorMessage)
        .task {
            do {
                rooms = try await appState.roomService.fetchRooms(propertyId: propertyId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private var vacantRooms: [Room] {
        rooms.filter { $0.roomType == .privateRoom && !$0.occupied }
    }

}
