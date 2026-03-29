import Auth
import SwiftUI

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
                    title: String(localized: "No invitations", locale: LanguageService.currentLocale, comment: "Empty state title when no invitations"),
                    subtitle: String(localized: "You have no pending invitations", locale: LanguageService.currentLocale, comment: "Empty state subtitle for invitations")
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
        .navigationTitle(String(localized: "My invitations", locale: LanguageService.currentLocale, comment: "Navigation title for invitations list"))
        .errorAlert($errorMessage)
        .task {
            await loadInvitations()
        }
        .refreshable {
            await loadInvitations()
        }
    }

    private func loadInvitations() async {
        guard let email = appState.authService.currentUserEmail else {
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
            try await appState.propertyService.acceptInvitation(
                token: invitation.token, userId: userId)
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
                    Text("Property invitation", comment: "Invitation card title")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(String(localized: "Role", locale: LanguageService.currentLocale, comment: "Invitation role label")): \(invitation.role.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("Expires: \(invitation.expiresAt.shortFormatted)", comment: "Invitation expiry date")
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
                    Text("Accept", comment: "Accept invitation button")
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
                    Text("Reject", comment: "Reject invitation button")
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
