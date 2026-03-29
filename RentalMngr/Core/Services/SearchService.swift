import Foundation
import Supabase

struct SearchResults: Sendable {
    let properties: [Property]
    let rooms: [Room]
    let tenants: [Tenant]

    var isEmpty: Bool {
        properties.isEmpty && rooms.isEmpty && tenants.isEmpty
    }

    var totalCount: Int {
        properties.count + rooms.count + tenants.count
    }
}

final class SearchService: SearchServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func search(query: String) async throws -> SearchResults {
        // Sanitize input to prevent PostgREST filter issues
        let sanitized =
            query
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            return SearchResults(properties: [], rooms: [], tenants: [])
        }
        let pattern = "%\(sanitized)%"

        async let properties: [Property] =
            client
            .from(SupabaseTable.properties)
            .select()
            .or("name.ilike.\(pattern),address.ilike.\(pattern)")
            .limit(5)
            .execute()
            .value

        async let rooms: [Room] =
            client
            .from(SupabaseTable.rooms)
            .select()
            .or("name.ilike.\(pattern),tenant_name.ilike.\(pattern)")
            .limit(5)
            .execute()
            .value

        async let tenants: [Tenant] =
            client
            .from(SupabaseTable.tenants)
            .select()
            .or("full_name.ilike.\(pattern),email.ilike.\(pattern),phone.ilike.\(pattern)")
            .limit(5)
            .execute()
            .value

        return SearchResults(
            properties: try await properties,
            rooms: try await rooms,
            tenants: try await tenants
        )
    }
}
