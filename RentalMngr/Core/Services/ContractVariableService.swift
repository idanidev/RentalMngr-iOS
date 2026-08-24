import Foundation
import Supabase

final class ContractVariableService: Sendable {
    private var client: SupabaseClient { SupabaseService.shared.client }

    /// Cacheado igual que el perfil: se pide desde cada pantalla de contrato.
    func fetchVariables() async throws -> [ContractVariable] {
        try await StableDataCache.shared.value(for: StableDataKey.contractVariables) {
            try await self.fetchVariablesUncached()
        }
    }

    private func fetchVariablesUncached() async throws -> [ContractVariable] {
        let userId = try await client.auth.session.user.id.uuidString
        return try await client
            .from(SupabaseTable.contractVariables)
            .select()
            .eq("user_id", value: userId)
            .order("created_at")
            .execute()
            .value
    }

    func createVariable(name: String, label: String, defaultValue: String) async throws -> ContractVariable {
        await StableDataCache.shared.invalidate(StableDataKey.contractVariables)
        let userId = try await client.auth.session.user.id.uuidString

        struct NewVariable: Encodable {
            let name: String
            let label: String
            let default_value: String
            let user_id: String
        }

        let variable: ContractVariable = try await client
            .from(SupabaseTable.contractVariables)
            .insert(NewVariable(name: name, label: label, default_value: defaultValue, user_id: userId))
            .select()
            .single()
            .execute()
            .value

        return variable
    }

    func updateVariable(_ variable: ContractVariable) async throws {
        await StableDataCache.shared.invalidate(StableDataKey.contractVariables)
        struct UpdatePayload: Encodable {
            let name: String
            let label: String
            let default_value: String
        }

        try await client
            .from(SupabaseTable.contractVariables)
            .update(UpdatePayload(name: variable.name, label: variable.label, default_value: variable.defaultValue))
            .eq("id", value: variable.id)
            .execute()
    }

    func deleteVariable(id: UUID) async throws {
        await StableDataCache.shared.invalidate(StableDataKey.contractVariables)
        try await client
            .from(SupabaseTable.contractVariables)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
