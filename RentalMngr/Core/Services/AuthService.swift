import Auth
import Foundation
import Supabase

@MainActor @Observable
final class AuthService: AuthServiceProtocol {
    var currentSession: Session?
    var currentUser: User?
    var isAuthenticated = false
    var isLoading = true

    private var client: SupabaseClient { SupabaseService.shared.client }

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        currentSession = response.session
        currentUser = response.session?.user
        isAuthenticated = response.session != nil
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        currentSession = session
        currentUser = session.user
        isAuthenticated = true
    }

    func signOut() async throws {
        // Remove this device's push token while still authenticated (RLS needs the session),
        // so the signed-out user stops receiving the prior account's notifications.
        await PushManager.shared?.clearOnSignOut()
        // No arrastrar datos de una cuenta a la siguiente.
        await StableDataCache.shared.clearAll()
        try await client.auth.signOut()
        currentSession = nil
        currentUser = nil
        isAuthenticated = false
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    /// Verify the 6-digit recovery code that Supabase emails after `resetPasswordForEmail`,
    /// then immediately update the password. Requires Supabase email template to send
    /// `{{ .Token }}` instead of `{{ .ConfirmationURL }}`.
    func verifyPasswordResetOTP(email: String, token: String, newPassword: String) async throws {
        try await client.auth.verifyOTP(
            email: email,
            token: token,
            type: .recovery
        )
        try await client.auth.update(user: UserAttributes(password: newPassword))
        // Force re-login with new password
        try await client.auth.signOut()
        currentSession = nil
        currentUser = nil
        isAuthenticated = false
    }

    func observeAuthState() async {
        for await (event, session) in client.auth.authStateChanges {
            guard [.initialSession, .signedIn, .signedOut, .tokenRefreshed].contains(event) else {
                continue
            }

            if let session {
                if session.isExpired {
                    // Session is expired — try to refresh it
                    do {
                        let refreshed = try await client.auth.refreshSession()
                        self.currentSession = refreshed
                        self.currentUser = refreshed.user
                        self.isAuthenticated = true
                    } catch {
                        // Refresh failed — user needs to log in again
                        self.currentSession = nil
                        self.currentUser = nil
                        self.isAuthenticated = false
                    }
                } else {
                    self.currentSession = session
                    self.currentUser = session.user
                    self.isAuthenticated = true
                }
            } else {
                self.currentSession = nil
                self.currentUser = nil
                self.isAuthenticated = false
            }
            self.isLoading = false
        }
    }

    func deleteAccount() async throws {
        // Remove this device's push token while still authenticated (RLS needs the session).
        await PushManager.shared?.clearOnSignOut()
        // Las fotos van ANTES del RPC: el borrado en cascada elimina las filas
        // de `rooms`, y sin ellas ya no hay forma de saber qué ficheros del
        // bucket eran de este usuario. Quedarían huérfanos para siempre, que es
        // justo lo que RGPD no permite.
        await deleteOwnedPhotos()
        // Call the delete_account RPC which removes all user data + auth.users entry server-side
        try await client.rpc("delete_account").execute()
        // Purge the persisted session too — otherwise `emitLocalSessionAsInitialSession`
        // re-authenticates the now-deleted account into the app on next launch.
        try? await client.auth.signOut(scope: .local)
        currentSession = nil
        currentUser = nil
        isAuthenticated = false
    }

    /// Borra del bucket todas las fotos de las habitaciones del usuario, y sus
    /// miniaturas. Best-effort: si algo falla no se aborta el borrado de cuenta,
    /// porque dejar la cuenta a medio borrar es peor que dejar un fichero suelto.
    private func deleteOwnedPhotos() async {
        struct RoomPhotos: Decodable { let photos: [String]? }
        struct PropertyRooms: Decodable { let rooms: [RoomPhotos]? }

        guard let uid = currentUser?.id else { return }
        do {
            let properties: [PropertyRooms] = try await client
                .from(SupabaseTable.properties)
                .select("rooms(photos)")
                .eq("owner_id", value: uid)
                .execute()
                .value

            let paths = properties
                .flatMap { $0.rooms ?? [] }
                .flatMap { $0.photos ?? [] }
            guard !paths.isEmpty else { return }

            // Originales y miniaturas de una vez.
            let all = paths + paths.map(StoragePaths.thumbnail(for:))
            try await client.storage
                .from(SupabaseConfig.storageBucket)
                .remove(paths: all)
        } catch {
            // Sin drama: el borrado de cuenta sigue adelante.
        }
    }

    var currentUserId: UUID? {
        currentUser?.id
    }

    var currentUserEmail: String? {
        currentUser?.email
    }
}
