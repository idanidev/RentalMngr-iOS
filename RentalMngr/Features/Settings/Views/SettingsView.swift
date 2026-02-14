import SwiftUI
import Auth

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignOutConfirmation = false

    var body: some View {
        List {
            // Profile
            Section("Perfil") {
                if let email = appState.authService.currentUser?.email {
                    LabeledContent("Email", value: email)
                }
                if let id = appState.authService.currentUserId {
                    LabeledContent("ID", value: String(id.uuidString.prefix(8)) + "...")
                }
            }

            // Navigation
            Section("Herramientas") {
                NavigationLink {
                    SearchView()
                } label: {
                    Label("Buscar", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    MyInvitationsView()
                } label: {
                    Label("Mis invitaciones", systemImage: "envelope.badge")
                }

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("Ajustes de avisos", systemImage: "bell.badge")
                }
            }

            // App info
            Section("Aplicación") {
                LabeledContent("Versión", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            }

            // Sign out
            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Más")
        .confirmationDialog("¿Cerrar sesión?", isPresented: $showSignOutConfirmation) {
            Button("Cerrar sesión", role: .destructive) {
                Task {
                    try? await appState.authService.signOut()
                }
            }
        } message: {
            Text("Se cerrará tu sesión actual")
        }
    }
}
