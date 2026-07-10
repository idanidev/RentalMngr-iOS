import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "DeviceTokenService")

protocol DeviceTokenServiceProtocol: Sendable {
    /// Insert or update this device's APNs token for the given user.
    func upsertToken(userId: UUID, token: String, platform: String) async throws
    /// Remove a device token (e.g. on sign-out).
    func deleteToken(_ token: String) async throws
}

/// Persists APNs device tokens in the Supabase `device_tokens` table so the
/// backend (Edge Function) can target this device with remote push.
final class DeviceTokenService: DeviceTokenServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func upsertToken(userId: UUID, token: String, platform: String) async throws {
        struct Row: Encodable {
            let user_id: UUID
            let token: String
            let platform: String
        }
        // `token` is the conflict target (unique) so re-registering updates the owner.
        try await client
            .from(SupabaseTable.deviceTokens)
            .upsert(Row(user_id: userId, token: token, platform: platform), onConflict: "token")
            .execute()
    }

    func deleteToken(_ token: String) async throws {
        try await client
            .from(SupabaseTable.deviceTokens)
            .delete()
            .eq("token", value: token)
            .execute()
    }
}
