import SwiftUI
import Auth

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var welcomeMessage: String?

    var body: some View {
        Group {
            if appState.authService.isLoading {
                LoadingView(message: "Cargando...")
            } else if appState.authService.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.smooth, value: appState.authService.isAuthenticated)
        .task {
            await appState.authService.observeAuthState()
        }
        .onChange(of: appState.authService.isAuthenticated) { _, isAuth in
            if isAuth {
                Task { await processPendingInvitations() }
            }
        }
        .alert("¡Bienvenido!", isPresented: Binding(
            get: { welcomeMessage != nil },
            set: { if !$0 { welcomeMessage = nil } }
        )) {
            Button("OK") { welcomeMessage = nil }
        } message: {
            if let msg = welcomeMessage {
                Text(msg)
            }
        }
    }

    /// Auto-process pending invitations on login (matches webapp layout.svelte)
    private func processPendingInvitations() async {
        guard let userId = appState.authService.currentUserId,
              let email = appState.authService.currentUser?.email else { return }
        do {
            let grantedNames = try await appState.propertyService.processPendingInvitations(
                userId: userId, email: email
            )
            if !grantedNames.isEmpty {
                welcomeMessage = "Se te ha dado acceso a: \(grantedNames.joined(separator: ", "))"
            }
        } catch {
            // Silently fail - non-critical operation
        }
    }
}
