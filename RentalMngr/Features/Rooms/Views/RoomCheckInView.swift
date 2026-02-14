import SwiftUI

struct RoomCheckInView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let room: Room
    let propertyId: UUID

    @State private var availableTenants: [Tenant] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if availableTenants.isEmpty {
                EmptyStateView(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "Sin inquilinos disponibles",
                    subtitle: "Todos los inquilinos ya tienen habitación asignada o no hay inquilinos activos"
                )
            } else {
                List(availableTenants) { tenant in
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
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tenant.fullName)
                                    .font(.headline)
                                if let email = tenant.email, !email.isEmpty {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let rent = tenant.monthlyRent {
                                    Text(formatCurrency(rent) + "/mes")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.title3)
                        }
                    }
                }
            }
        }
        .navigationTitle("Check-in: \(room.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
        .errorAlert($errorMessage)
        .task {
            do {
                availableTenants = try await appState.tenantService.fetchAvailableTenants(propertyId: propertyId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
