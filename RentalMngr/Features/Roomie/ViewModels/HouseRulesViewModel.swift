import Foundation

@Observable
final class HouseRulesViewModel {
    var rules: [HouseRule] = []
    var isLoading = false
    var errorMessage: String?

    let propertyId: UUID
    private let houseRuleService: HouseRuleService

    init(propertyId: UUID, houseRuleService: HouseRuleService) {
        self.propertyId = propertyId
        self.houseRuleService = houseRuleService
    }

    func loadRules() async {
        isLoading = true
        do {
            rules = try await houseRuleService.fetchRules(propertyId: propertyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteRule(_ rule: HouseRule) async {
        do {
            try await houseRuleService.deleteRule(id: rule.id)
            rules.removeAll { $0.id == rule.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var rulesByCategory: [HouseRuleCategory: [HouseRule]] {
        Dictionary(grouping: rules, by: \.category)
    }
}
