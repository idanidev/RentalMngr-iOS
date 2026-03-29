import Auth
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            // Profile
            Section(
                String(localized: "Profile", locale: LanguageService.currentLocale, comment: "Settings section header for user profile")
            ) {
                Text(appState.authService.currentUserEmail ?? "Unknown User")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(
                String(localized: "Landlord Details",
                    locale: LanguageService.currentLocale, comment: "Settings section header for landlord information")
            ) {
                NavigationLink {
                    LandlordProfileView()
                } label: {
                    Label(
                        String(localized: "Edit Profile",
                            locale: LanguageService.currentLocale, comment: "Label for navigating to edit landlord profile"),
                        systemImage: "person.text.rectangle")
                }
            }

            // Appearance
            Section(
                String(localized: "Appearance",
                    locale: LanguageService.currentLocale, comment: "Settings section header for appearance options")
            ) {
                @Bindable var bindableAppState = appState
                Picker(
                    String(localized: "Theme", locale: LanguageService.currentLocale, comment: "Picker label for selecting app theme"),
                    selection: $bindableAppState.userInterfaceStyle
                ) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.displayName, systemImage: theme.icon)
                            .tag(theme)
                    }
                }
                .pickerStyle(.menu)
            }

            // Navigation
            Section(
                String(localized: "Tools", locale: LanguageService.currentLocale, comment: "Settings section header for tools and utilities")
            ) {
                NavigationLink {
                    SearchView()
                } label: {
                    Label(
                        String(localized: "Search", locale: LanguageService.currentLocale, comment: "Label for navigating to search"),
                        systemImage: "magnifyingglass")
                }

                NavigationLink {
                    MyInvitationsView()
                } label: {
                    Label(
                        String(localized: "My Invitations",
                            locale: LanguageService.currentLocale, comment: "Label for navigating to invitations list"),
                        systemImage: "envelope.badge")
                }

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label(
                        String(localized: "Notification Settings",
                            locale: LanguageService.currentLocale, comment: "Label for navigating to notification settings"),
                        systemImage: "bell.badge")
                }
            }

            // App info
            Section(
                String(localized: "App", locale: LanguageService.currentLocale, comment: "Settings section header for app information")
            ) {
                LabeledContent(
                    String(localized: "Version", locale: LanguageService.currentLocale, comment: "Label for app version number"),
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                        ?? "1.0")
                LabeledContent(
                    String(localized: "Build", locale: LanguageService.currentLocale, comment: "Label for app build number"),
                    value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                )
            }

            if appState.authService.currentUserEmail == "idanibenito@gmail.com" {
                Section("Super User") {
                    Button("Resetear Onboarding (slides)") {
                        hasSeenOnboarding = false
                    }
                    Button("Resetear Asistente de configuración") {
                        hasCompletedSetup = false
                    }
                    Button("Resetear todo el Onboarding") {
                        hasSeenOnboarding = false
                        hasCompletedSetup = false
                    }
                }
                .foregroundStyle(.orange)
            }

            // Sign out
            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Label(
                        String(localized: "Sign Out",
                            locale: LanguageService.currentLocale, comment: "Button label for signing out of the app"),
                        systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            // Delete account — required by Apple App Store Review Guidelines §5.1.1
            Section {
                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                } label: {
                    if isDeletingAccount {
                        HStack {
                            ProgressView()
                            Text(
                                String(localized: "Deleting account…",
                                    locale: LanguageService.currentLocale, comment: "Loading state while deleting account"))
                        }
                    } else {
                        Label(
                            String(localized: "Delete Account",
                                locale: LanguageService.currentLocale, comment: "Button label for permanently deleting the account"),
                            systemImage: "person.crop.circle.badge.minus")
                    }
                }
                .disabled(isDeletingAccount)
            } footer: {
                Text(
                    String(localized:
                            "Permanently deletes your account and all associated data. This action cannot be undone.",
                        locale: LanguageService.currentLocale, comment: "Footer warning for delete account section"))
            }
        }
        .navigationTitle(
            String(localized: "More", locale: LanguageService.currentLocale, comment: "Navigation title for settings/more screen")
        )
        .confirmationDialog(
            String(localized: "Sign Out Confirmation Title", defaultValue: "Sign out?",
                locale: LanguageService.currentLocale, comment: "Confirmation dialog title for sign out"),
            isPresented: $showSignOutConfirmation
        ) {
            Button(
                String(localized: "Sign Out", locale: LanguageService.currentLocale, comment: "Destructive button to confirm sign out"),
                role: .destructive
            ) {
                Task {
                    do {
                        try await appState.authService.signOut()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text(
                String(localized: "Your current session will be closed",
                    locale: LanguageService.currentLocale, comment: "Confirmation dialog message for sign out"))
        }
        .confirmationDialog(
            String(localized: "Delete Account?",
                locale: LanguageService.currentLocale, comment: "Confirmation dialog title for permanent account deletion"),
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "Delete Account Permanently",
                    locale: LanguageService.currentLocale, comment: "Destructive confirmation button for account deletion"),
                role: .destructive
            ) {
                Task {
                    isDeletingAccount = true
                    do {
                        try await appState.authService.deleteAccount()
                    } catch {
                        errorMessage = error.localizedDescription
                        isDeletingAccount = false
                    }
                }
            }
            Button(
                String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button in confirmation dialog"),
                role: .cancel
            ) {}
        } message: {
            Text(
                String(localized:
                        "All your data — properties, tenants, finances — will be permanently erased. This cannot be undone.",
                    locale: LanguageService.currentLocale, comment: "Confirmation message for permanent account deletion"))
        }
        .errorAlert($errorMessage)
    }
}
