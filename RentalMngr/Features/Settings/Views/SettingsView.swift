import Auth
import StoreKit
import SwiftUI

struct SettingsView: View {
    /// Whether to show the "Done" close button. True when presented as a sheet
    /// (avatar), false when shown as the "More" tab (nothing to dismiss).
    var showsDoneButton: Bool = true
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var showSignOutConfirmation = false
    @State private var pendingAction: DestructiveAction?
    @State private var isDeletingAccount = false
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    @Environment(\.openURL) private var openURL

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

            // Premium / Suscripción
            Section("Suscripción") {
                premiumRow
                manageSubscriptionRow
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

            // Contracts
            Section(
                String(localized: "Contracts", locale: LanguageService.currentLocale, comment: "Settings section header for contracts")
            ) {
                NavigationLink {
                    ContractVariablesView()
                } label: {
                    Label(
                        String(localized: "Contract variables",
                            locale: LanguageService.currentLocale, comment: "Label for navigating to contract variables editor"),
                        systemImage: "curlybraces")
                }
            }

            // Security
            if appState.appLockManager.isBiometricAvailable {
                Section {
                    Toggle(isOn: Binding(
                        get: { appState.appLockManager.isBiometricEnabled },
                        set: { _ in
                            Task {
                                _ = await appState.appLockManager.toggleBiometric()
                            }
                        }
                    )) {
                        Label(
                            String(localized: "Bloqueo con \(appState.appLockManager.biometryTypeName)", locale: LanguageService.currentLocale),
                            systemImage: "lock.shield"
                        )
                    }
                } header: {
                    Text(String(localized: "Security", locale: LanguageService.currentLocale, comment: "Settings section header for security options"))
                } footer: {
                    Text(String(localized: "Solicita autenticación biométrica tras 30 segundos en segundo plano", locale: LanguageService.currentLocale))
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
                    pendingAction = deleteAccountConfirmation
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
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", locale: LanguageService.currentLocale, comment: "Button to close the settings screen")) {
                        dismiss()
                    }
                }
            }
        }
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
                        errorMessage = error.safeUserMessage
                    }
                }
            }
        } message: {
            Text(
                String(localized: "Your current session will be closed",
                    locale: LanguageService.currentLocale, comment: "Confirmation dialog message for sign out"))
        }
        .destructiveConfirmation($pendingAction)
        .errorAlert($errorMessage)
        #if !targetEnvironment(macCatalyst)
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        #endif
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(appState.entitlementService)
        }
        .task {
            // Refresh tier when entering Settings
            if let uid = appState.authService.currentUser?.id {
                await appState.entitlementService.refresh(userId: uid)
            }
        }
    }

    /// Borrar la cuenta es irreversible y se lleva la base entera del usuario.
    /// El diálogo del sistema no da sitio para enumerar qué desaparece, y aquí
    /// esa lista es justo lo que hace pensárselo dos veces.
    private var deleteAccountConfirmation: DestructiveAction {
        DestructiveAction(
            title: String(localized: "¿Borrar tu cuenta?", locale: LanguageService.currentLocale, comment: "Delete account title"),
            message: String(localized: "Se borran tus propiedades, tus inquilinos, tus finanzas y tus documentos. No hay copia de seguridad y no se puede deshacer.", locale: LanguageService.currentLocale, comment: "Delete account message"),
            confirmLabel: String(localized: "Borrar mi cuenta", locale: LanguageService.currentLocale, comment: "Confirm delete account"),
            icon: "person.crop.circle.badge.xmark",
            perform: {
                isDeletingAccount = true
                do {
                    try await appState.authService.deleteAccount()
                } catch {
                    errorMessage = error.safeUserMessage
                    isDeletingAccount = false
                }
            })
    }

    /// Apple exige (y el usuario agradece) poder cancelar sin buscar cuatro
    /// niveles dentro de Ajustes. En iOS abre la hoja nativa de suscripciones;
    /// en Mac Catalyst esa hoja no existe, así que se abre la página de la cuenta.
    private var manageSubscriptionRow: some View {
        Button {
            #if targetEnvironment(macCatalyst)
                if let url = URL(string: "macappstore://apps.apple.com/account/subscriptions") {
                    openURL(url)
                }
            #else
                showManageSubscriptions = true
            #endif
        } label: {
            Label(
                String(localized: "Gestionar o cancelar suscripción", locale: LanguageService.currentLocale, comment: "Manage subscription row"),
                systemImage: "creditcard")
        }
    }

    @ViewBuilder
    private var premiumRow: some View {
        let entitlement = appState.entitlementService
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(tierLabel(entitlement.tier))
                            .font(.headline)
                        if entitlement.isPremium {
                            PremiumBadge()
                        }
                    }
                    Text(tierSubtitle(entitlement))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !entitlement.isPremium {
                    Button("Hazte Premium") { showPaywall = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else {
                    Button("Ver beneficios") { showPaywall = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            HStack(spacing: 8) {
                Button {
                    Task { await forceRefreshTier() }
                } label: {
                    Label(
                        entitlement.isLoading ? "Comprobando..." : "Refrescar estado",
                        systemImage: "arrow.clockwise"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(entitlement.isLoading)

                if let err = entitlement.lastError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: hSize == .regular ? .infinity : nil, alignment: .leading)
        .padding(hSize == .regular ? 16 : 0)
        .background(hSize == .regular ? AnyShapeStyle(.background.secondary) : AnyShapeStyle(.clear))
        .overlay {
            if hSize == .regular {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: hSize == .regular ? 18 : 0))
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .macCardHover()
    }

    private func forceRefreshTier() async {
        guard let uid = appState.authService.currentUser?.id
            ?? appState.authService.currentUserId else {
            return
        }
        await appState.entitlementService.refresh(userId: uid)
        #if DEBUG
        if let sub = appState.entitlementService.subscription {
            print("[Entitlement] tier=\(sub.tier.rawValue) expires=\(sub.expiresAt?.description ?? "nil") provider=\(sub.provider ?? "nil")")
        } else {
            print("[Entitlement] subscription is nil — query returned no rows")
        }
        #endif
    }

    private func tierLabel(_ t: SubscriptionTier) -> String {
        switch t {
        case .free: "Plan gratuito"
        case .premium: "Plan Premium"
        case .admin: "Cuenta Admin"
        }
    }

    private func tierSubtitle(_ e: EntitlementService) -> String {
        switch e.tier {
        case .admin: "Acceso total · de por vida"
        case .premium:
            if let exp = e.subscription?.expiresAt {
                "Renueva el \(exp.formatted(date: .abbreviated, time: .omitted))"
            } else { "Activo · sin caducidad" }
        case .free:
            "1 propiedad · 2 habitaciones · sin generación de PDF"
        }
    }
}
