import Foundation

enum AccessRole: String, Codable, Sendable, CaseIterable {
    case owner
    case editor
    case viewer

    var displayName: String {
        switch self {
        case .owner: String(localized: "Owner", locale: LanguageService.currentLocale, comment: "Access role")
        case .editor: String(localized: "Editor", locale: LanguageService.currentLocale, comment: "Access role")
        case .viewer: String(localized: "Viewer", locale: LanguageService.currentLocale, comment: "Access role")
        }
    }
}

struct PropertyAccess: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    let userId: UUID
    let role: AccessRole
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, role
        case propertyId = "property_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

// MARK: - RPC Models, DTOs & Params

struct PropertyMember: Decodable, Identifiable, Sendable, Hashable {
    let userId: UUID
    let role: AccessRole
    let email: String

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case email
    }
}

struct RemoveAccessParams: Encodable, Sendable {
    let p_property_id: UUID
    let p_user_id: UUID

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_property_id, forKey: .p_property_id)
        try container.encode(p_user_id, forKey: .p_user_id)
    }

    enum CodingKeys: String, CodingKey {
        case p_property_id, p_user_id
    }
}

struct UpdateAccess: Encodable, Sendable {
    let role: String

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
    }

    enum CodingKeys: String, CodingKey {
        case role
    }
}

struct GetUserByEmailParams: Encodable, Sendable {
    let user_email: String

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(user_email, forKey: .user_email)
    }

    enum CodingKeys: String, CodingKey {
        case user_email
    }
}

struct UserEmailResult: Decodable, Sendable {
    let id: UUID
    let email: String
}

struct GrantAccessParams: Encodable, Sendable {
    let p_property_id: UUID
    let p_user_id: UUID
    let p_role: String

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_property_id, forKey: .p_property_id)
        try container.encode(p_user_id, forKey: .p_user_id)
        try container.encode(p_role, forKey: .p_role)
    }

    enum CodingKeys: String, CodingKey {
        case p_property_id, p_user_id, p_role
    }
}

struct NewInvitation: Encodable, Sendable {
    let property_id: UUID
    let email: String
    let role: String
    let created_by: UUID
    let expires_at: String

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(property_id, forKey: .property_id)
        try container.encode(email, forKey: .email)
        try container.encode(role, forKey: .role)
        try container.encode(created_by, forKey: .created_by)
        try container.encode(expires_at, forKey: .expires_at)
    }

    enum CodingKeys: String, CodingKey {
        case property_id, email, role, created_by, expires_at
    }
}

struct GetPropertyMembersParams: Encodable, Sendable {
    let p_property_id: UUID

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_property_id, forKey: .p_property_id)
    }

    enum CodingKeys: String, CodingKey {
        case p_property_id
    }
}

enum InviteResult: Sendable {
    case direct  // User existed, access granted immediately
    case pending  // User doesn't exist, invitation created
}
