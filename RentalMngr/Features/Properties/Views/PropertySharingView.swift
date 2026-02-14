import SwiftUI

struct PropertySharingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let property: Property

    @State private var email = ""
    @State private var selectedRole: AccessRole = .viewer
    @State private var invitations: [Invitation] = []
    @State private var accessList: [PropertyAccess] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        List {
            Section("Invitar usuario") {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)

                Picker("Rol", selection: $selectedRole) {
                    Text("Visor").tag(AccessRole.viewer)
                    Text("Editor").tag(AccessRole.editor)
                }

                Button("Enviar invitación") {
                    Task { await sendInvitation() }
                }
                .disabled(email.isEmpty || isLoading)
            }

            if !accessList.isEmpty {
                Section("Usuarios con acceso") {
                    ForEach(accessList) { access in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(access.userId.uuidString.prefix(8) + "...")
                                    .font(.subheadline)
                                Text(access.role.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if access.role != .owner {
                                Button(role: .destructive) {
                                    Task { await removeAccess(access) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
            }

            if !invitations.isEmpty {
                Section("Invitaciones pendientes") {
                    ForEach(invitations) { invitation in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(invitation.email)
                                    .font(.subheadline)
                                Text("\(invitation.role.rawValue.capitalized) · Expira: \(invitation.expiresAt.shortFormatted)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await revokeInvitation(invitation) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }

            if let success = successMessage {
                Section {
                    Text(success).foregroundStyle(.green).font(.caption)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle("Compartir")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
        .task {
            await loadAccessData()
        }
    }

    private func loadAccessData() async {
        do {
            async let access = appState.propertyService.getPropertyAccess(propertyId: property.id)
            async let pending = appState.propertyService.getPendingInvitations(propertyId: property.id)
            accessList = try await access
            invitations = try await pending
        } catch {
            errorMessage = error.localizedDescription
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
                successMessage = "✓ Acceso concedido directamente a \(email)"
            case .pending:
                successMessage = "✓ Invitación enviada a \(email)"
            }
            email = ""
            await loadAccessData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func removeAccess(_ access: PropertyAccess) async {
        do {
            try await appState.propertyService.removeAccess(propertyId: property.id, userId: access.userId)
            await loadAccessData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revokeInvitation(_ invitation: Invitation) async {
        do {
            try await appState.propertyService.revokeInvitation(id: invitation.id)
            await loadAccessData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
