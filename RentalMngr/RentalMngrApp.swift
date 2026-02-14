import SwiftUI

@main
struct RentalMngrApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .task {
                    do {
                        try await appState.financeService.generateMonthlyIncome()
                        print("[RentalMngrApp] Monthly income check completed")
                    } catch {
                        print("[RentalMngrApp] Error generating monthly income: \(error)")
                    }
                }
        }
    }
}
