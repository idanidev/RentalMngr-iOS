import Foundation
import Supabase

final class HouseRuleService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func fetchRules(propertyId: UUID) async throws -> [HouseRule] {
        try await client
            .from("house_rules")
            .select()
            .eq("property_id", value: propertyId)
            .order("category")
            .execute()
            .value
    }

    func createRule(propertyId: UUID, category: HouseRuleCategory, title: String,
                    description: String?, createdBy: UUID) async throws -> HouseRule {
        struct NewRule: Encodable {
            let property_id: UUID
            let category: String
            let title: String
            let description: String?
            let created_by: UUID
        }
        return try await client
            .from("house_rules")
            .insert(NewRule(property_id: propertyId, category: category.rawValue,
                            title: title, description: description, created_by: createdBy))
            .select()
            .single()
            .execute()
            .value
    }

    func updateRule(_ rule: HouseRule) async throws -> HouseRule {
        struct UpdateRule: Encodable {
            let category: String
            let title: String
            let description: String?
        }
        return try await client
            .from("house_rules")
            .update(UpdateRule(category: rule.category.rawValue, title: rule.title, description: rule.description))
            .eq("id", value: rule.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteRule(id: UUID) async throws {
        try await client
            .from("house_rules")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
