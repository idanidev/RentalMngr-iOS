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
    /// Último plan comprado en esta sesión: lo usa el aviso de fin de prueba.
    private(set) var lastPurchasedProduct: Product?

    /// Product identifier configured in App Store Connect / .storekit file.
    /// Must match exactly the IAP product created.
    static let monthlyPremiumId = "idanidev.RentalMngr.premium.monthly"
    static let yearlyPremiumId = "idanidev.RentalMngr.premium.yearly"
    static var allProductIds: [String] { [monthlyPremiumId, yearlyPremiumId] }

    /// Convenience: the premium subscription product if loaded.
    var monthlyPremium: Product? {
        products.first { $0.id == Self.monthlyPremiumId }
    }

    var yearlyPremium: Product? {
        products.first { $0.id == Self.yearlyPremiumId }
    }

    /// Precio ya formateado por StoreKit (moneda y región del usuario).
    /// Nunca escribimos un precio a mano: si el producto no carga, no se anuncia.
    var monthlyPriceFormatted: String { monthlyPremium?.displayPrice ?? "—" }
    var yearlyPriceFormatted: String { yearlyPremium?.displayPrice ?? "—" }

    /// Ahorro del plan anual frente a pagar 12 meses sueltos, redondeado.
    var yearlySavingsPercent: Int? {
        guard let monthly = monthlyPremium?.price, let yearly = yearlyPremium?.price, monthly > 0 else { return nil }
        let twelve = monthly * Decimal(12)
        guard twelve > yearly else { return nil }
        let ratio = NSDecimalNumber(decimal: (twelve - yearly) / twelve).doubleValue
        return Int((ratio * 100).rounded())
    }

    /// Días de prueba gratuita que Apple tiene configurados para el producto.
    /// Se lee de StoreKit: si en App Store Connect no hay oferta, devuelve nil y
    /// la interfaz NO anuncia ninguna prueba (anunciar una que no existe = rechazo).
    func freeTrialDays(for product: Product?) -> Int? {
        guard let offer = product?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        switch period.unit {
        case .day:   return period.value
        case .week:  return period.value * 7
        case .month: return period.value * 30
        case .year:  return period.value * 365
        @unknown default: return nil
        }
    }

    /// Fecha en la que termina la prueba, para poder avisar antes de que se cobre.
    func trialEndDate(for product: Product?) -> Date? {
        guard let days = freeTrialDays(for: product) else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: Date())
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
            products = try await Product.products(for: Self.allProductIds)
        } catch {
            lastError = "No se pudieron cargar los productos: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    /// Purchase the monthly subscription. Returns true on confirmed success.
    @discardableResult
    func buyMonthlyPremium() async -> Bool {
        await buy(monthlyPremium)
    }

    /// Compra cualquiera de los planes. Devuelve true si Apple completó el cobro.
    @discardableResult
    func buy(_ target: Product?) async -> Bool {
        guard let product = target else {
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
                // Apple ya ha cobrado. Si el servidor no registra la compra, NO
                // finalizamos: StoreKit la reentrega en `Transaction.updates` y se
                // reintenta. Finalizarla aquí sería cobrar sin dar el servicio.
                let synced = await syncToServer(transaction: transaction, product: product)
                purchasedProductIds.insert(product.id)
                lastPurchasedProduct = product
                entitlementService?.setStoreKitEntitlement(true)
                if synced {
                    await transaction.finish()
                }
                return true
            case .userCancelled:
                return false
            case .pending:
                // Ask to Buy / SCA: se resolverá sola y llegará por Transaction.updates.
                lastError = "Compra pendiente de aprobación. Se activará sola en cuanto se apruebe."
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
        defer { entitlementService?.setStoreKitEntitlement(!purchasedProductIds.isEmpty) }
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
                    // Reintento de una compra que quedó sin registrar: solo se
                    // finaliza cuando el servidor la acepta.
                    let synced = await self.handleUpdatedTransaction(transaction)
                    if synced {
                        await transaction.finish()
                    }
                }
            }
        }
    }

    /// Procesa una transacción reentregada por StoreKit. Devuelve `true` si el
    /// servidor la registró y por tanto puede finalizarse.
    private func handleUpdatedTransaction(_ transaction: Transaction) async -> Bool {
        guard transaction.revocationDate == nil,
              (transaction.expirationDate ?? .distantFuture) > Date() else {
            // Reembolsada o caducada: se finaliza para no reintentarla eternamente.
            entitlementService?.setStoreKitEntitlement(false)
            return true
        }
        guard let product = monthlyPremium else { return false }
        entitlementService?.setStoreKitEntitlement(true)
        return await syncToServer(transaction: transaction, product: product)
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
    /// - Returns: `true` solo si el servidor registró la compra. El llamante NO debe
    ///   dar por finalizada la transacción si esto devuelve `false`.
    @discardableResult
    private func syncToServer(transaction: Transaction, product: Product) async -> Bool {
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
            return true
        } catch {
            lastError = "No se pudo activar premium en el servidor. Lo reintentaremos automáticamente."
            return false
        }
    }
}
