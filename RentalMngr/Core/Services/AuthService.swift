import Auth
import Foundation
import Supabase

@Observable
final class AuthService {
    var currentSession: Session?
    var currentUser: User?
    var isAuthenticated = false
    var isLoading = true
    var errorMessage: String?

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
        try await client.auth.signOut()
        currentSession = nil
        currentUser = nil
        isAuthenticated = false
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
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

    var currentUserId: UUID? {
        currentUser?.id
    }
}
