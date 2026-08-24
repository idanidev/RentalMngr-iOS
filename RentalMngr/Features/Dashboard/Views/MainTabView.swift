import StoreKit
import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        @Bindable var bindable = appState

        // Native tab bar. It can't host a long-press, so the property switcher is
        // opened by re-tapping the Properties tab while already on it.
        let selection = Binding(
            get: { appState.selectedTab },
            set: { newValue in
                if newValue == .properties && appState.selectedTab == .properties {
                    appState.showPropertySwitcher = true
                }
                appState.selectedTab = newValue
            }
        )

        TabView(selection: selection) {
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

            Tab(
                String(localized: "More", locale: LanguageService.currentLocale, comment: "Tab bar item for settings/more"),
                systemImage: "ellipsis",
                value: AppTab.more
            ) {
                NavigationStack {
                    SettingsView(showsDoneButton: false)
                }
            }
        }
        // iPhone/iPad: sidebar adaptable. Mac Catalyst: keep the iOS-style bottom
        // tab bar (no sidebar) — the sidebar left big empty columns on Mac.
        #if !targetEnvironment(macCatalyst)
            .tabViewStyle(.sidebarAdaptable)
        #endif
        .sheet(isPresented: $bindable.showPropertySwitcher) {
            PropertySwitcherView()
        }
        // Ask for a review only after the app has earned it (see ReviewPrompter).
        .onChange(of: appState.reviewPrompter.shouldPrompt) { _, earned in
            guard earned else { return }
            appState.reviewPrompter.consume()
            requestReview()
        }
    }
}
