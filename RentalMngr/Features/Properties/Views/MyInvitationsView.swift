import SwiftUI
import Auth

struct MyInvitationsView: View {
    @Environment(AppState.self) private var appState
    @State private var invitations: [Invitation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var processedMessage: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if invitations.isEmpty {
                EmptyStateView(
                    icon: "envelope.open",
                    title: "Sin invitaciones",
                    subtitle: "No tienes invitaciones pendientes"
                )
            } else {
                List {
                    ForEach(invitations) { invitation in
                        InvitationCard(
                            invitation: invitation,
                            onAccept: { await acceptInvitation(invitation) },
                            onReject: { await rejectInvitation(invitation) }
                        )
                    }
                }
            }
        }
        .navigationTitle("Mis invitaciones")
        .errorAlert($errorMessage)
        .task {
            await loadInvitations()
        }
        .refreshable {
            await loadInvitations()
        }
    }

    private func loadInvitations() async {
        guard let email = appState.authService.currentUser?.email else {
            isLoading = false
            return
        }
        do {
            invitations = try await appState.propertyService.getMyInvitations(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func acceptInvitation(_ invitation: Invitation) async {
        guard let userId = appState.authService.currentUserId else { return }
        do {
            try await appState.propertyService.acceptInvitation(token: invitation.token, userId: userId)
            invitations.removeAll { $0.id == invitation.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rejectInvitation(_ invitation: Invitation) async {
        do {
            try await appState.propertyService.rejectInvitation(id: invitation.id)
            invitations.removeAll { $0.id == invitation.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct InvitationCard: View {
    let invitation: Invitation
    let onAccept: () async -> Void
    let onReject: () async -> Void
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invitación a propiedad")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Rol: \(invitation.role.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("Expira: \(invitation.expiresAt.shortFormatted)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    isProcessing = true
                    Task {
                        await onAccept()
                        isProcessing = false
                    }
                } label: {
                    Text("Aceptar")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isProcessing)

                Button(role: .destructive) {
                    isProcessing = true
                    Task {
                        await onReject()
                        isProcessing = false
                    }
                } label: {
                    Text("Rechazar")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 4)
    }
}
