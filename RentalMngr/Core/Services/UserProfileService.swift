import Foundation
import Supabase

final class UserProfileService: UserProfileServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    private struct LandlordProfileRow: Codable, Sendable {
        var userId: String?
        var fullName: String
        var dni: String
        var address: String
        var email: String
        var phone: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case fullName = "full_name"
            case dni
            case address
            case email
            case phone
        }
    }

    func getLandlordProfile() async throws -> LandlordProfile {
        let userId = try await client.auth.session.user.id.uuidString

        let rows: [LandlordProfileRow] = try await client
            .from(SupabaseTable.landlordProfiles)
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            return .empty
        }

        return LandlordProfile(
            fullName: row.fullName,
            dni: row.dni,
            address: row.address,
            email: row.email,
            phone: row.phone
        )
    }

    func saveLandlordProfile(_ profile: LandlordProfile) async throws {
        let userId = try await client.auth.session.user.id.uuidString

        try await client
            .from(SupabaseTable.landlordProfiles)
            .upsert(
                LandlordProfileRow(
                    userId: userId,
                    fullName: profile.fullName,
                    dni: profile.dni,
                    address: profile.address,
                    email: profile.email,
                    phone: profile.phone
                ),
                onConflict: "user_id"
            )
            .execute()
    }
}
