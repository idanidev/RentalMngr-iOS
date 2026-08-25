import SwiftUI

struct PropertySharingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let property: Property

    @State private var email = ""
    @State private var selectedRole: AccessRole = .viewer
    @State private var invitations: [Invitation] = []
    @State private var accessList: [PropertyMember] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    /// Acción destructiva pendiente de confirmar. Quitar el acceso a alguien no
    /// puede dispararse de un solo toque sin avisar.
    @State private var pendingAction: DestructiveAction?

    var body: some View {
        List {

            if let success = successMessage {

                Section {

                    Label(success, systemImage: "checkmark.circle.fill")

                        .foregroundStyle(.green)

                        .font(.subheadline)

                }

            }

            Section(String(localized: "Invite user", locale: LanguageService.currentLocale, comment: "Section header for inviting users")) {
                TextField(String(localized: "Email", locale: LanguageService.currentLocale, comment: "Email field for invitation"), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)

                Picker(String(localized: "Role", locale: LanguageService.currentLocale, comment: "Role picker label"), selection: $selectedRole) {
                    Text("Viewer", comment: "Viewer access role").tag(AccessRole.viewer)
                    Text("Editor", comment: "Editor access role").tag(AccessRole.editor)
                }

                Button(String(localized: "Send invitation", locale: LanguageService.currentLocale, comment: "Send invitation button")) {
                    Task { await sendInvitation() }
                }
                .disabled(email.isEmpty || isLoading)
            }

            if !accessList.isEmpty {
                Section(String(localized: "Users with access", locale: LanguageService.currentLocale, comment: "Section header for users who have access")) {
                    ForEach(accessList) { access in
                        HStack {
                            VStack(alignment: .leading) {
                                if access.userId == appState.authService.currentUserId {
                                    Text("You", comment: "Label indicating current user")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(access.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(access.email)
                                        .font(.subheadline)
                                }
                                if access.userId == appState.authService.currentUserId {
                                    Text(access.role.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Menu {
                                        Picker(
                                            String(localized: "Role", locale: LanguageService.currentLocale, comment: "Access role picker"),
                                            selection: Binding(
                                                get: { access.role },
                                                set: { newRole in
                                                    Task {
                                                        await updateAccess(access, newRole: newRole)
                                                    }
                                                }
                                            )
                                        ) {
                                            Text(AccessRole.viewer.displayName).tag(AccessRole.viewer)
                                            Text(AccessRole.editor.displayName).tag(AccessRole.editor)
                                            if access.role == .owner {
                                                Text(AccessRole.owner.displayName).tag(AccessRole.owner)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(access.role.rawValue.capitalized)
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.blue.opacity(0.1), in: Capsule())
                                    }
                                }
                            }
                            Spacer()
                            if access.role != .owner {
                                Button(role: .destructive) {
                                    pendingAction = DestructiveAction(
                                        title: String(localized: "¿Quitar el acceso a \(access.email)?", locale: LanguageService.currentLocale, comment: "Confirm remove access title"),
                                        message: String(localized: "Dejará de ver esta propiedad y sus inquilinos. No se borra ningún dato, y podrás volver a invitarle cuando quieras.", locale: LanguageService.currentLocale, comment: "Confirm remove access message"),
                                        confirmLabel: String(localized: "Quitar acceso", locale: LanguageService.currentLocale, comment: "Confirm remove access button"),
                                        icon: "person.badge.minus"
                                    ) { await removeAccess(access) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .accessibilityLabel(String(localized: "Quitar acceso", locale: LanguageService.currentLocale, comment: "Accessibility label for remove access button"))
                            }
                        }
                    }
                }
            }

            if !invitations.isEmpty {
                Section(String(localized: "Pending invitations", locale: LanguageService.currentLocale, comment: "Section header for pending invitations")) {
                    ForEach(invitations) { invitation in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(invitation.email)
                                    .font(.subheadline)
                                Text(
                                    "\(invitation.role.displayName) · \(String(localized: "Expires", locale: LanguageService.currentLocale, comment: "Invitation expiry")): \(invitation.expiresAt.shortFormatted)"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                pendingAction = DestructiveAction(
                                    title: String(localized: "¿Cancelar la invitación a \(invitation.email)?", locale: LanguageService.currentLocale, comment: "Confirm revoke invitation title"),
                                    message: String(localized: "El enlace dejará de funcionar. Puedes volver a invitarle en cualquier momento.", locale: LanguageService.currentLocale, comment: "Confirm revoke invitation message"),
                                    confirmLabel: String(localized: "Cancelar invitación", locale: LanguageService.currentLocale, comment: "Confirm revoke invitation button"),
                                    icon: "envelope.badge.shield.half.filled"
                                ) { await revokeInvitation(invitation) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .accessibilityLabel(String(localized: "Revocar invitación", locale: LanguageService.currentLocale, comment: "Accessibility label for revoke invitation button"))
                        }
                    }
                }
            }


        }
        .navigationTitle(String(localized: "Share", locale: LanguageService.currentLocale, comment: "Share property navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Close", locale: LanguageService.currentLocale, comment: "Close button")) { dismiss() }
            }
        }
        .task {
            await loadAccessData()
        }
        .destructiveConfirmation($pendingAction)
        .errorAlert($errorMessage, context: "Compartir propiedad")
    }

    private func loadAccessData() async {
        do {
            async let access = appState.propertyService.getPropertyMembers(propertyId: property.id)
            async let pending = appState.propertyService.getPendingInvitations(
                propertyId: property.id)
            accessList = try await access
            invitations = try await pending
        } catch {
            errorMessage = error.safeUserMessage
        }
    }

    private func sendInvitation() async {
        guard let userId = appState.authService.currentUserId else { return }
        isLoading = true
        successMessage = nil
        do {
            let result = try await appState.propertyService.inviteUser(
                propertyId: property.id, email: email, role: selectedRole, createdBy: userId
            )
            switch result {
            case .direct:
                successMessage = String(localized: "✓ Access granted directly to \(email)", locale: LanguageService.currentLocale, comment: "Success message when direct access is granted")
            case .pending:
                successMessage = String(localized: "✓ Invitation sent to \(email)", locale: LanguageService.currentLocale, comment: "Success message when invitation is sent")
            }
            email = ""
            await loadAccessData()
        } catch {
            errorMessage = error.safeUserMessage
        }
        isLoading = false
    }

    private func removeAccess(_ access: PropertyMember) async {
        do {
            try await appState.propertyService.removeAccess(
                propertyId: property.id, userId: access.userId)
            await loadAccessData()
            successMessage = String(localized: "Se ha quitado el acceso a \(access.email)", locale: LanguageService.currentLocale, comment: "Access removed confirmation")
        } catch {
            errorMessage = error.safeUserMessage
        }
    }

    private func updateAccess(_ access: PropertyMember, newRole: AccessRole) async {
        guard access.role != newRole else { return }
        isLoading = true
        do {
            try await appState.propertyService.updateAccess(
                propertyId: property.id, userId: access.userId, role: newRole)
            await loadAccessData()
            successMessage = String(localized: "✓ Role updated successfully", locale: LanguageService.currentLocale, comment: "Success message when role is updated")
        } catch {
            errorMessage = error.safeUserMessage
            // Reload to reset UI state on error
            await loadAccessData()
        }
        isLoading = false
    }

    private func revokeInvitation(_ invitation: Invitation) async {
        do {
            try await appState.propertyService.revokeInvitation(id: invitation.id)
            await loadAccessData()
        } catch {
            errorMessage = error.safeUserMessage
        }
    }
}
