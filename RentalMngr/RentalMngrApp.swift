import SwiftUI

@main
struct RentalMngrApp: App {
    @State private var appState = AppState()
    @AppStorage("weeklyReportWeekday") private var weeklyReportWeekday: Int = 2

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.locale, appState.languageService.selectedLanguage.locale)
                .id(appState.languageService.selectedLanguage)
                .task {
                    // Request notification permissions
                    _ = try? await appState.notificationService.requestLocalPermission()
                    // Ensure rent reminders are scheduled
                    await appState.notificationService.scheduleRentReminders()
                    // Sync weekly report schedule based on saved settings
                    if let userId = appState.authService.currentUserId,
                       let settings = try? await appState.notificationService.fetchSettings(
                           userId: userId)
                    {
                        if settings.enableWeeklyReport {
                            await appState.notificationService.scheduleWeeklyReport(weekday: weeklyReportWeekday)
                        } else {
                            appState.notificationService.cancelWeeklyReport()
                        }
                    }
                }
                .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
    }
}
