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
                LoadingView()
            }
        }
        .navigationTitle("Normas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: {
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
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HouseRulesViewModel(propertyId: propertyId, houseRuleService: appState.houseRuleService)
            }
        }
        .task {
            await viewModel?.loadRules()
        }
    }

    @ViewBuilder
    private func rulesContent(_ vm: HouseRulesViewModel) -> some View {
        if vm.rules.isEmpty {
            EmptyStateView(icon: "list.clipboard", title: "Sin normas", subtitle: "Añade normas de convivencia",
                           actionTitle: "Añadir norma") { showAddSheet = true }
        } else {
            List {
                ForEach(vm.rulesByCategory.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { category, rules in
                    Section(category.rawValue.capitalized) {
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
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
