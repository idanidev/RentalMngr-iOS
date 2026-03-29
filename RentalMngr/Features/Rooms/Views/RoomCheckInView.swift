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
                    title: String(localized: "No available tenants", locale: LanguageService.currentLocale, comment: "Empty state title when no tenants available for check-in"),
                    subtitle: String(localized: "All tenants already have an assigned room or there are no active tenants", locale: LanguageService.currentLocale, comment: "Empty state subtitle for no available tenants")
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
                                    Text(rent.formatted(currencyCode: "EUR") + String(localized: "/mo", locale: LanguageService.currentLocale, comment: "Monthly rent abbreviation suffix"))
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
        .navigationTitle(String(localized: "Check-in: \(room.name)", locale: LanguageService.currentLocale, comment: "Navigation title for check-in with room name"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Button to cancel")) { dismiss() }
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

}
