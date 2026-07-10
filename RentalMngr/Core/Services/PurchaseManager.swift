import Foundation
import StoreKit
import Supabase

private struct ApplyPremiumPurchaseParams: Encodable, Sendable {
    let p_transaction_id: String
    let p_expires_at: String
    let p_provider: String
}

extension ApplyPremiumPurchaseParams {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_transaction_id, forKey: .p_transaction_id)
        try c.encode(p_expires_at, forKey: .p_expires_at)
        try c.encode(p_provider, forKey: .p_provider)
    }
    enum CodingKeys: String, CodingKey { case p_transaction_id, p_expires_at, p_provider }
}

/// StoreKit 2 purchase manager for the Premium subscription.
///
/// Handles: product loading, purchase, restore, transaction listener, server-side sync via Supabase RPC.
///
/// **TODO (production)**: Replace `apply_premium_purchase` client-trusted RPC with Apple App Store
/// Server-to-Server Notifications V2 → Supabase Edge Function that validates receipt with Apple.
/// Current implementation is acceptable for v1 (RLS still scopes to auth.uid()).
@MainActor @Observable
final class PurchaseManager {

    // MARK: - Public state
    private(set) var products: [Product] = []
    private(set) var purchasedProductIds: Set<String> = []
    private(set) var isLoading = false
    private(set) var purchaseInProgress = false
    private(set) var lastError: String?

    /// Product identifier configured in App Store Connect / .storekit file.
    /// Must match exactly the IAP product created.
    static let monthlyPremiumId = "idanidev.RentalMngr.premium.monthly"

    /// Convenience: the premium subscription product if loaded.
    var monthlyPremium: Product? {
        products.first { $0.id == Self.monthlyPremiumId }
    }

    /// Localized price string (e.g. "5,99 €") taken from StoreKit. Falls back to "5,99 €".
    var monthlyPriceFormatted: String {
        monthlyPremium?.displayPrice ?? "5,99 €"
    }

    // MARK: - Lifecycle
    private var transactionListener: Task<Void, Never>?
    private weak var entitlementService: EntitlementService?
    private var client: SupabaseClient { SupabaseService.shared.client }

    init() {
        transactionListener = listenForTransactions()
    }

    // Note: cannot cancel listener from deinit (main-actor isolation). The Task is detached
    // and tied to the manager's lifetime via [weak self] — it self-terminates when self deallocates.

    /// Inject after init (called from AppState).
    func bind(entitlementService: EntitlementService) {
        self.entitlementService = entitlementService
    }

    // MARK: - Product loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.monthlyPremiumId])
        } catch {
            lastError = "No se pudieron cargar los productos: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    /// Purchase the monthly subscription. Returns true on confirmed success.
    @discardableResult
    func buyMonthlyPremium() async -> Bool {
        guard let product = monthlyPremium else {
            lastError = "Producto no disponible. ¿Configurado en App Store Connect?"
            return false
        }
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await syncToServer(transaction: transaction, product: product)
                await transaction.finish()
                purchasedProductIds.insert(product.id)
                return true
            case .userCancelled:
                return false
            case .pending:
                lastError = "Compra pendiente de aprobación."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.safeUserMessage
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshActiveSubscriptions()
        } catch {
            lastError = "Restauración falló: \(error.localizedDescription)"
        }
    }

    /// Scan all current entitlements and re-sync to server.
    func refreshActiveSubscriptions() async {
        purchasedProductIds.removeAll()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.monthlyPremiumId,
               transaction.revocationDate == nil,
               (transaction.expirationDate ?? .distantFuture) > Date() {
                purchasedProductIds.insert(transaction.productID)
                if let product = monthlyPremium {
                    await syncToServer(transaction: transaction, product: product)
                }
            }
        }
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await MainActor.run { [self] in
                        if let product = self.monthlyPremium {
                            Task { await self.syncToServer(transaction: transaction, product: product) }
                        }
                    }
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Server sync (Supabase RPC)

    /// Push successful purchase to Supabase. RPC `apply_premium_purchase` upserts user_subscriptions.
    private func syncToServer(transaction: Transaction, product: Product) async {
        let expiresIso = ISO8601DateFormatter().string(
            from: transaction.expirationDate ?? Date().addingTimeInterval(60 * 60 * 24 * 30)
        )
        do {
            try await client.rpc(
                "apply_premium_purchase",
                params: ApplyPremiumPurchaseParams(
                    p_transaction_id: String(transaction.id),
                    p_expires_at: expiresIso,
                    p_provider: "apple"
                )
            ).execute()
            // Refresh entitlement to reflect new tier in UI
            if let entitlement = entitlementService,
               let userId = SupabaseService.shared.client.auth.currentUser?.id {
                await entitlement.refresh(userId: userId)
            }
        } catch {
            lastError = "No se pudo activar premium en servidor: \(error.localizedDescription)"
        }
    }
}
