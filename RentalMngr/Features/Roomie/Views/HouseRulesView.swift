import SwiftUI

struct HouseRulesView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HouseRulesViewModel?
    @State private var showAddSheet = false
    let propertyId: UUID

    var body: some View {
        Group {
            if let vm = viewModel {
                rulesContent(vm)
            } else {
                // Skeleton Loading
                List {
                    ForEach(0..<5) { _ in
                        VStack(alignment: .leading, spacing: 4) {
                            SkeletonView().frame(width: 150, height: 20)
                            SkeletonView().frame(width: 250, height: 14)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(
            String(localized: "House rules", locale: LanguageService.currentLocale, comment: "Navigation title for house rules list")
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let vm = viewModel { Task { await vm.loadRules() } }
        } content: {
            NavigationStack {
                HouseRuleFormView(propertyId: propertyId)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HouseRulesViewModel(
                    propertyId: propertyId, houseRuleService: appState.houseRuleService)
            }
        }
        .task {
            await viewModel?.loadRules()
        }
    }

    @ViewBuilder
    private func rulesContent(_ vm: HouseRulesViewModel) -> some View {
        if vm.rules.isEmpty {
            EmptyStateView(
                icon: "list.clipboard",
                title: String(localized: "No rules", locale: LanguageService.currentLocale, comment: "Empty state title when no house rules exist"),
                subtitle: String(localized: "Add house rules for cohabitation",
                    locale: LanguageService.currentLocale, comment: "Empty state subtitle for house rules"),
                actionTitle: String(localized: "Add rule", locale: LanguageService.currentLocale, comment: "Button to add a new house rule")
            ) { showAddSheet = true }
        } else {
            List {
                ForEach(
                    vm.rulesByCategory.sorted(by: { $0.key.displayName < $1.key.displayName }),
                    id: \.key
                ) { category, rules in
                    Section(category.displayName) {
                        ForEach(rules) { rule in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.title).font(.subheadline).fontWeight(.semibold)
                                if let desc = rule.description, !desc.isEmpty {
                                    Text(desc).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.deleteRule(rule) }
                                } label: {
                                    Label(
                                        String(localized: "Delete",
                                            locale: LanguageService.currentLocale, comment: "Swipe action to delete a house rule"),
                                        systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .refreshable {
                await vm.loadRules()
            }
        }
    }
}
