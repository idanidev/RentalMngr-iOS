import Auth
import SwiftUI
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "ContentView")

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    /// Prevents setup screen from flashing while we check if the user has existing properties.
    @State private var setupCheckComplete = false
    @State private var welcomeMessage: String?

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else if appState.authService.isLoading
                || (appState.authService.isAuthenticated && !setupCheckComplete)
            {
                LoadingView(
                    message: String(localized: "Loading...", locale: LanguageService.currentLocale, comment: "Loading screen message"))
            } else if appState.authService.isAuthenticated {
                if !hasCompletedSetup {
                    OnboardingSetupView()
                        .transition(.opacity)
                } else {
                    MainTabView()
                }
            } else {
                AuthView()
            }
        }
        .animation(.smooth, value: appState.authService.isAuthenticated)
        .animation(.smooth, value: hasCompletedSetup)
        .animation(.smooth, value: setupCheckComplete)
        .task {
            await appState.authService.observeAuthState()
        }
        .task(id: appState.authService.isAuthenticated) {
            guard appState.authService.isAuthenticated else {
                setupCheckComplete = false
                return
            }

            // Resolve setup state BEFORE showing any screen — avoids flashing the
            // setup wizard for existing users who already have properties.
            if !hasCompletedSetup,
                let props = try? await appState.propertyService.fetchProperties(),
                !props.isEmpty
            {
                hasCompletedSetup = true
            }
            setupCheckComplete = true

            await processPendingInvitations()

            // Generate monthly income after login
            do {
                try await appState.financeService.generateMonthlyIncome()
                logger.info("Monthly income generation completed")
            } catch {
                logger.error("Monthly income generation failed: \(error.localizedDescription)")
            }

            // Generate monthly utility charges for all properties
            do {
                let properties = try await appState.propertyService.fetchProperties()
                try await appState.utilityService.generateMonthlyUtilityCharges(
                    properties: properties)
                logger.info("Monthly utility charge generation completed")
            } catch {
                logger.error(
                    "Monthly utility charge generation failed: \(error.localizedDescription)")
            }
        }
        .alert(
            String(localized: "Welcome!", locale: LanguageService.currentLocale, comment: "Welcome alert title"),
            isPresented: Binding(
                get: { welcomeMessage != nil },
                set: { if !$0 { welcomeMessage = nil } }
            )
        ) {
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
            let email = appState.authService.currentUserEmail
        else { return }
        do {
            let grantedNames = try await appState.propertyService.processPendingInvitations(
                userId: userId, email: email
            )
            if !grantedNames.isEmpty {
                let names = grantedNames.joined(separator: ", ")
                welcomeMessage = String(
                    localized: "You have been granted access to: \(names)",
                    locale: LanguageService.currentLocale,
                    comment: "Welcome message after invitation accepted"
                )
            }
        } catch {
            // Silently fail - non-critical operation
        }
    }
}
