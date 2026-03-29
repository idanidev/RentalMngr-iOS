import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var bindable = appState

        TabView(selection: $bindable.selectedTab) {
            Tab(
                String(localized: "Home", locale: LanguageService.currentLocale, comment: "Tab bar item for dashboard"),
                systemImage: "house.fill",
                value: AppTab.dashboard
            ) {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab(
                String(localized: "Properties", locale: LanguageService.currentLocale, comment: "Tab bar item for properties"),
                systemImage: "building.2.fill",
                value: AppTab.properties
            ) {
                NavigationStack(path: $bindable.propertiesNavigationPath) {
                    PropertyListView()
                }
            }

            Tab(
                String(localized: "Finances", locale: LanguageService.currentLocale, comment: "Tab bar item for finances"),
                systemImage: "chart.line.uptrend.xyaxis",
                value: AppTab.finances
            ) {
                NavigationStack {
                    GlobalFinanceView()
                }
            }
        }
    }
}
