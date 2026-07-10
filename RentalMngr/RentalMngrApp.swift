import SwiftUI

@main
struct RentalMngrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    /// Returns the mockup screen requested via launch env var `MOCKUP_SCREEN`, if any.
    /// Used to capture marketing screenshots without backend/auth.
    private var mockupScreen: MockupShowcase.Screen? {
        guard let raw = ProcessInfo.processInfo.environment["MOCKUP_SCREEN"] else { return nil }
        return MockupShowcase.Screen(rawValue: raw)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let screen = mockupScreen {
                    MockupShowcaseView(screen: screen)
                } else {
                    ContentView()
                }
            }
                .environment(appState)
                .environment(\.locale, appState.languageService.selectedLanguage.locale)
                .id(appState.languageService.selectedLanguage)
                .task {
                    // Request permission and register with APNs. The notification
                    // schedule + token sync are built from ContentView when the
                    // session resolves — at this point the userId is still nil and
                    // rescheduling here would be a no-op (or worse, a wipe).
                    let granted = (try? await appState.notificationService.requestLocalPermission()) ?? false
                    if granted {
                        appState.pushManager.registerForRemoteNotifications()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Re-sync on every foreground so the schedule never drifts and
                    // reflects data/settings changes made while the app was away.
                    guard phase == .active else { return }
                    Task {
                        await appState.localNotificationScheduler.rescheduleAll(
                            userId: appState.authService.currentUserId)
                    }
                }
                .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
    }
}
