import Foundation
import Supabase

protocol ContractTemplateServiceProtocol: Sendable {
    func getTemplate() async throws -> String
    func saveTemplate(_ text: String) async throws
}

/// Stores contract templates per user in Supabase `contract_templates` table.
/// New users start with an empty template — they write their own.
final class ContractTemplateService: ContractTemplateServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    private struct ContractTemplateRow: Codable, Sendable {
        var id: UUID?
        var userId: String?
        var templateText: String

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case templateText = "template_text"
        }
    }

    func getTemplate() async throws -> String {
        let userId = try await client.auth.session.user.id.uuidString

        let rows: [ContractTemplateRow] = try await client
            .from("contract_templates")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        return rows.first?.templateText ?? ""
    }

    func saveTemplate(_ text: String) async throws {
        let userId = try await client.auth.session.user.id.uuidString

        // Upsert: insert if not exists, update if exists (unique on user_id)
        try await client
            .from("contract_templates")
            .upsert(
                ContractTemplateRow(userId: userId, templateText: text),
                onConflict: "user_id"
            )
            .execute()
    }
}
