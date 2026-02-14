import Foundation
import Supabase

final class PropertyService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    /// Fetch all properties the current user has access to, WITH rooms embedded
    /// Matches webapp: getUserProperties(userId) → SELECT *, rooms(*)
    func fetchProperties() async throws -> [Property] {
        // Step 1: Get property IDs the user has access to
        let accessList: [PropertyAccess] =
            try await client
            .from("property_access")
            .select()
            .execute()
            .value

        print("[PropertyService] Access list count: \(accessList.count)")
        guard !accessList.isEmpty else { return [] }

        let propertyIds = accessList.map(\.propertyId)
        print("[PropertyService] Property IDs: \(propertyIds)")

        // Step 2: Get properties WITH rooms (joined)
        do {
            let properties: [Property] =
                try await client
                .from("properties")
                .select("*, rooms(*)")
                .in("id", values: propertyIds)
                .order("created_at", ascending: false)
                .execute()
                .value
            print("[PropertyService] Successfully decoded \(properties.count) properties")
            return properties
        } catch {
            print("[PropertyService] Bulk decoding error: \(error)")
            // Fallback: try loading each property individually
            var properties: [Property] = []
            for pid in propertyIds {
                do {
                    let p: Property =
                        try await client
                        .from("properties")
                        .select("*, rooms(*)")
                        .eq("id", value: pid)
                        .single()
                        .execute()
                        .value
                    properties.append(p)
                } catch {
                    print("[PropertyService] Failed to decode property \(pid): \(error)")
                }
            }
            return properties
        }
    }

    /// Fetch a single property WITH rooms embedded
    func fetchProperty(id: UUID) async throws -> Property {
        try await client
            .from("properties")
            .select("*, rooms(*)")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createProperty(name: String, address: String, description: String?, ownerId: UUID)
        async throws -> Property
    {
        struct NewProperty: Encodable {
            let name: String
            let address: String
            let description: String?
            let owner_id: UUID
        }
        return
            try await client
            .from("properties")
            .insert(
                NewProperty(
                    name: name, address: address, description: description, owner_id: ownerId)
            )
            .select("*, rooms(*)")
            .single()
            .execute()
            .value
    }

    func updateProperty(_ property: Property) async throws -> Property {
        struct UpdateProperty: Encodable {
            let name: String
            let address: String
            let description: String?
        }
        return
            try await client
            .from("properties")
            .update(
                UpdateProperty(
                    name: property.name, address: property.address,
                    description: property.description)
            )
            .eq("id", value: property.id)
            .select("*, rooms(*)")
            .single()
            .execute()
            .value
    }

    func deleteProperty(id: UUID) async throws {
        try await client
            .from("properties")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Access & Invitations

    func getPropertyAccess(propertyId: UUID) async throws -> [PropertyAccess] {
        try await client
            .from("property_access")
            .select()
            .eq("property_id", value: propertyId)
            .execute()
            .value
    }

    /// Smart invite: if user exists → grant direct access, if not → create pending invitation
    /// Matches webapp: permissionsService.inviteUser()
    enum InviteResult {
        case direct  // User existed, access granted immediately
        case pending  // User doesn't exist, invitation created
    }

    func inviteUser(propertyId: UUID, email: String, role: AccessRole, createdBy: UUID) async throws
        -> InviteResult
    {
        // Step 1: Check if user exists via RPC
        let params = GetUserByEmailParams(user_email: email)
        let existingUsers: [UserEmailResult] =
            try await client
            .rpc("get_user_by_email", params: params)
            .execute()
            .value

        if let existingUser = existingUsers.first {
            // User exists → grant direct access via RPC
            let grantParams = GrantAccessParams(
                p_property_id: propertyId,
                p_user_id: existingUser.id,
                p_role: role.rawValue
            )
            try await client
                .rpc("grant_property_access", params: grantParams)
                .execute()
            return .direct
        } else {
            // User doesn't exist → create pending invitation
            let expiresAt = ISO8601DateFormatter().string(
                from: Calendar.current.date(byAdding: .day, value: 30, to: Date())!
            )
            try await client
                .from("invitations")
                .insert(
                    NewInvitation(
                        property_id: propertyId, email: email,
                        role: role.rawValue, created_by: createdBy,
                        expires_at: expiresAt
                    )
                )
                .execute()
            return .pending
        }
    }

    func getPendingInvitations(propertyId: UUID) async throws -> [Invitation] {
        try await client
            .from("invitations")
            .select()
            .eq("property_id", value: propertyId)
            .execute()
            .value
    }

    /// Get invitations sent TO the current user's email
    func getMyInvitations(email: String) async throws -> [Invitation] {
        let now = ISO8601DateFormatter().string(from: Date())
        return
            try await client
            .from("invitations")
            .select()
            .eq("email", value: email)
            .gt("expires_at", value: now)
            .execute()
            .value
    }

    /// Accept an invitation: calls grant_property_access RPC + deletes invitation
    func acceptInvitation(token: UUID, userId: UUID) async throws {
        // Get the invitation by token
        let invitation: Invitation =
            try await client
            .from("invitations")
            .select()
            .eq("token", value: token)
            .single()
            .execute()
            .value

        // Grant access via RPC (the RPC validates the invitation internally)
        let grantParams = GrantAccessParams(
            p_property_id: invitation.propertyId,
            p_user_id: userId,
            p_role: invitation.role.rawValue
        )
        try await client
            .rpc("grant_property_access", params: grantParams)
            .execute()

        // Delete the invitation
        try await client
            .from("invitations")
            .delete()
            .eq("token", value: token)
            .execute()
    }

    /// Reject/decline an invitation
    func rejectInvitation(id: UUID) async throws {
        try await client
            .from("invitations")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func revokeInvitation(id: UUID) async throws {
        try await client
            .from("invitations")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Auto-process pending invitations on login (matches webapp layout.svelte)
    func processPendingInvitations(userId: UUID, email: String) async throws -> [String] {
        let now = ISO8601DateFormatter().string(from: Date())
        let pendingInvitations: [Invitation] =
            try await client
            .from("invitations")
            .select()
            .eq("email", value: email)
            .gt("expires_at", value: now)
            .execute()
            .value

        var grantedPropertyNames: [String] = []

        for invitation in pendingInvitations {
            // Check if user already has access
            let existing: [PropertyAccess] =
                try await client
                .from("property_access")
                .select()
                .eq("property_id", value: invitation.propertyId)
                .eq("user_id", value: userId)
                .execute()
                .value

            if existing.isEmpty {
                // Grant access
                let grantParams = GrantAccessParams(
                    p_property_id: invitation.propertyId,
                    p_user_id: userId,
                    p_role: invitation.role.rawValue
                )
                try await client
                    .rpc("grant_property_access", params: grantParams)
                    .execute()

                // Get property name for notification
                if let property = try? await fetchProperty(id: invitation.propertyId) {
                    grantedPropertyNames.append(property.name)
                }
            }

            // Delete the processed invitation
            try await client
                .from("invitations")
                .delete()
                .eq("id", value: invitation.id)
                .execute()
        }

        return grantedPropertyNames
    }

    func removeAccess(propertyId: UUID, userId: UUID) async throws {
        try await client
            .from("property_access")
            .delete()
            .eq("property_id", value: propertyId)
            .eq("user_id", value: userId)
            .execute()
    }

    /// Change user role for a property (matches webapp changeUserRole)
    func changeUserRole(propertyId: UUID, userId: UUID, newRole: AccessRole) async throws {
        struct RoleUpdate: Encodable {
            let role: String
        }
        try await client
            .from("property_access")
            .update(RoleUpdate(role: newRole.rawValue))
            .eq("property_id", value: propertyId)
            .eq("user_id", value: userId)
            .execute()
    }
}

// MARK: - RPC Parameter structs (file-level for actor isolation)

nonisolated private struct GetUserByEmailParams: Encodable, Sendable {
    let user_email: String
}

nonisolated private struct UserEmailResult: Decodable, Sendable {
    let id: UUID
    let email: String
}

nonisolated private struct GrantAccessParams: Encodable, Sendable {
    let p_property_id: UUID
    let p_user_id: UUID
    let p_role: String
}

nonisolated private struct NewInvitation: Encodable, Sendable {
    let property_id: UUID
    let email: String
    let role: String
    let created_by: UUID
    let expires_at: String
}
