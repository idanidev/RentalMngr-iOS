import SwiftUI

/// Property switcher presented by long-pressing the Properties tab. Picking a
/// property jumps straight to its detail (and switches to the Properties tab).
struct PropertySwitcherView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var properties: [Property] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if properties.isEmpty {
                    EmptyStateView(
                        icon: "building.2",
                        title: String(localized: "No properties", locale: LanguageService.currentLocale, comment: "Empty state title when no properties exist"),
                        subtitle: String(localized: "You have no registered properties", locale: LanguageService.currentLocale, comment: "Empty state subtitle for no properties")
                    )
                } else {
                    List(properties) { property in
                        Button { select(property) } label: { row(property) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(String(localized: "Switch property", locale: LanguageService.currentLocale, comment: "Title for property switcher dialog"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            properties = (try? await appState.propertyService.fetchProperties()) ?? []
            isLoading = false
        }
    }

    private func row(_ property: Property) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.indigo.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.indigo)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(property.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(property.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if property.id == appState.selectedProperty?.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.indigo)
            }
        }
        .contentShape(Rectangle())
    }

    private func select(_ property: Property) {
        appState.selectedTab = .properties
        appState.selectedProperty = property
        var path = NavigationPath()
        path.append(property)
        appState.propertiesNavigationPath = path
        dismiss()
    }
}
