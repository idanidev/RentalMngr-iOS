import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Inicio", systemImage: "house.fill", value: .dashboard) {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("Propiedades", systemImage: "building.2.fill", value: .properties) {
                NavigationStack {
                    PropertyListView()
                }
            }

            Tab("Finanzas", systemImage: "eurosign.circle.fill", value: .finances) {
                NavigationStack {
                    GlobalFinanceView()
                }
            }

            Tab("Avisos", systemImage: "bell.fill", value: .notifications) {
                NavigationStack {
                    NotificationListView()
                }
            }

            Tab("Más", systemImage: "ellipsis", value: .more) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}
