import Foundation
import Observation
import Supabase

/// Single source of truth for premium gating across the app.
///
/// Reads from Supabase `user_subscriptions`. Mirrors backend SQL `is_premium(uid)`.
/// Gate every premium-only feature through `requirePremium(_:)` or `isPremium`.
@MainActor @Observable
final class EntitlementService {
    private(set) var subscription: UserSubscription?
    private(set) var isLoading = false
    private(set) var lastError: String?

    private var client: SupabaseClient { SupabaseService.shared.client }

    /// Respaldo firmado por Apple. StoreKit conoce la suscripción aunque el
    /// servidor no responda, así que un cliente de pago sin cobertura (o en un
    /// arranque en frío con la red caída) no pierde el acceso que ha pagado.
    private(set) var storeKitActive = false

    /// True if user is admin or has active premium. Defaults to FALSE while loading.
    var isPremium: Bool { subscription?.isPremium == true || storeKitActive }
    var tier: SubscriptionTier { subscription?.tier ?? .free }
    var isAdmin: Bool { subscription?.tier == .admin }

    /// Refresh from server. Call on app start, after login, after purchase, on resume.
    func refresh(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let subs: [UserSubscription] = try await client
                .from(SupabaseTable.userSubscriptions)
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            // Trigger creates a free row on signup, but be defensive.
            subscription = subs.first ?? UserSubscription(
                userId: userId, tier: .free, expiresAt: nil,
                provider: nil, providerId: nil, autoRenew: false,
                createdAt: nil, updatedAt: nil
            )
        } catch {
            lastError = error.safeUserMessage
        }
    }

    /// Lo llama PurchaseManager tras consultar `Transaction.currentEntitlements`.
    func setStoreKitEntitlement(_ active: Bool) {
        storeKitActive = active
    }

    func clear() {
        subscription = nil
        storeKitActive = false
    }

    /// Throws `EntitlementError.premiumRequired` if user is not premium.
    /// Use as gate before performing premium actions.
    func requirePremium(feature: PremiumFeature) throws {
        guard isPremium else { throw EntitlementError.premiumRequired(feature) }
    }
}

enum PremiumFeature: String, Sendable {
    case unlimitedProperties
    case unlimitedRooms
    case contractPdf
    case roomAd
    case shareProperty
    case customVariables
    case multipleTemplates
    case unlimitedDocuments
    case fullFinanceHistory
    case dataExport

    var displayName: String {
        switch self {
        case .unlimitedProperties: "Propiedades ilimitadas"
        case .unlimitedRooms: "Habitaciones ilimitadas"
        case .contractPdf: "Generar contrato PDF"
        case .roomAd: "Generar anuncio de habitación"
        case .shareProperty: "Compartir propiedades"
        case .customVariables: "Variables personalizadas"
        case .multipleTemplates: "Múltiples plantillas"
        case .unlimitedDocuments: "Documentos ilimitados"
        case .fullFinanceHistory: "Histórico financiero completo"
        case .dataExport: "Exportar datos"
        }
    }
}

enum EntitlementError: LocalizedError {
    case premiumRequired(PremiumFeature)

    var errorDescription: String? {
        switch self {
        case .premiumRequired(let f): "Función premium: \(f.displayName)"
        }
    }
}

// MARK: - Free tier limits (mirror backend triggers)
enum FreeTierLimits {
    static let maxProperties = 1
    static let maxRoomsTotal = 2
    static let maxDocuments = 5
    static let financeHistoryMonths = 3
}
