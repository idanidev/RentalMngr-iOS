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

final class SearchService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func search(query: String) async throws -> SearchResults {
        let pattern = "%\(query)%"

        async let properties: [Property] = client
            .from("properties")
            .select()
            .or("name.ilike.\(pattern),address.ilike.\(pattern)")
            .limit(5)
            .execute()
            .value

        async let rooms: [Room] = client
            .from("rooms")
            .select()
            .or("name.ilike.\(pattern),tenant_name.ilike.\(pattern)")
            .limit(5)
            .execute()
            .value

        async let tenants: [Tenant] = client
            .from("tenants")
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
