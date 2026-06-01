import Foundation

enum SubscriptionTier: String, Codable, Sendable, CaseIterable {
    case free
    case premium
    case admin
}

struct UserSubscription: Codable, Sendable, Hashable {
    let userId: UUID
    var tier: SubscriptionTier
    var expiresAt: Date?
    var provider: String?
    var providerId: String?
    var autoRenew: Bool
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case tier, provider
        case userId = "user_id"
        case expiresAt = "expires_at"
        case providerId = "provider_id"
        case autoRenew = "auto_renew"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Mirrors backend `is_premium(uid)` SQL function. Single source of truth on client.
    var isPremium: Bool {
        switch tier {
        case .admin: return true
        case .premium:
            if let exp = expiresAt { return exp > Date() }
            return true   // null expires_at on premium = lifetime
        case .free: return false
        }
    }
}
