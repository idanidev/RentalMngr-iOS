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
                    title: "Sin habitaciones disponibles",
                    subtitle: "Todas las habitaciones están ocupadas"
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
                            Text(formatCurrency(room.monthlyRent) + "/mes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Asignar a \(tenant.fullName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
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

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
