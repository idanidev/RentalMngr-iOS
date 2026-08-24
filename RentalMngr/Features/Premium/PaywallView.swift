import Auth
import StoreKit
import Supabase
import SwiftUI

/// Pantalla de suscripción.
///
/// **Soft paywall a propósito**: siempre se puede cerrar. La app es útil en
/// gratis (3 unidades) y este panel aparece cuando el usuario choca con un
/// límite concreto, que es cuando ya entiende lo que gana pagando. Un hard
/// paywall en una herramienta con plan gratuito hunde el alta y se llena de
/// reseñas de una estrella — además, Apple exige una salida visible.
///
/// Contiene las piezas obligatorias de la Guideline 3.1.2: duración, precio por
/// periodo, renovación automática y enlaces a Términos y Privacidad.
struct PaywallView: View {
    let highlightedFeature: PremiumFeature?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(EntitlementService.self) private var entitlement
    @State private var errorMessage: String?
    @State private var selectedPlan: Plan = .yearly

    private enum Plan { case monthly, yearly }

    private var purchaseManager: PurchaseManager { appState.purchaseManager }
    private var isPurchasing: Bool { purchaseManager.purchaseInProgress }

    init(highlightedFeature: PremiumFeature? = nil) {
        self.highlightedFeature = highlightedFeature
    }

    private var selectedProduct: Product? {
        selectedPlan == .yearly ? purchaseManager.yearlyPremium : purchaseManager.monthlyPremium
    }

    /// Días de prueba REALES según App Store Connect. Si no hay oferta, no se
    /// anuncia ninguna prueba: prometer una que no existe es rechazo directo.
    private var trialDays: Int? {
        purchaseManager.freeTrialDays(for: selectedProduct)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroMedia                                   // 1. Media arriba
                    if let f = highlightedFeature { highlightCard(f) }
                    headlineAndBenefits                          // 3. Titular + beneficios
                    planOptions                                  // 4 y 5. Opciones + badges
                    subscribeButton                              // 7. Botón explícito
                    legalBlock                                   // 6. Términos visibles
                }
                .padding(20)
            }
            .navigationTitle(String(localized: "Premium", locale: LanguageService.currentLocale, comment: "Paywall navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 2. Soft paywall: salida siempre visible.
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cerrar", locale: LanguageService.currentLocale, comment: "Close paywall")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "Restaurar", locale: LanguageService.currentLocale, comment: "Restore purchases")) {
                        Task { await purchaseManager.restorePurchases() }
                    }
                    .disabled(isPurchasing)
                }
            }
            .task { await purchaseManager.loadProducts() }
            .errorAlert(Binding(get: { errorMessage }, set: { errorMessage = $0 }))
        }
    }

    // MARK: - 1. Media

    private var heroMedia: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [.orange.opacity(0.85), .pink.opacity(0.6), .indigo.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 10) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.white)
                Text(String(localized: "Tus alquileres, sin límites", locale: LanguageService.currentLocale, comment: "Paywall hero caption"))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 170)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 3. Titular y beneficios

    private var headlineAndBenefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Gestiona todas tus propiedades", locale: LanguageService.currentLocale, comment: "Paywall headline"))
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            benefit("infinity", String(localized: "Unidades ilimitadas: habitaciones o casas enteras", locale: LanguageService.currentLocale, comment: "Paywall benefit: unlimited units"))
            benefit("doc.text.fill", String(localized: "Contratos y anuncios en PDF sin límite", locale: LanguageService.currentLocale, comment: "Paywall benefit: unlimited PDFs"))
            benefit("chart.bar.doc.horizontal", String(localized: "Informe anual completo para la declaración", locale: LanguageService.currentLocale, comment: "Paywall benefit: annual report"))
            benefit("person.2.fill", String(localized: "Comparte cada propiedad con tu socio o gestor", locale: LanguageService.currentLocale, comment: "Paywall benefit: sharing"))
        }
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4 y 5. Opciones y badges

    private var planOptions: some View {
        VStack(spacing: 12) {
            planRow(
                plan: .yearly,
                title: String(localized: "Anual", locale: LanguageService.currentLocale, comment: "Yearly plan"),
                price: purchaseManager.yearlyPriceFormatted,
                period: String(localized: "al año", locale: LanguageService.currentLocale, comment: "per year"),
                badge: purchaseManager.yearlySavingsPercent.map {
                    String(localized: "Ahorra \($0)%", locale: LanguageService.currentLocale, comment: "Savings badge")
                } ?? String(localized: "Mejor valor", locale: LanguageService.currentLocale, comment: "Best value badge")
            )
            planRow(
                plan: .monthly,
                title: String(localized: "Mensual", locale: LanguageService.currentLocale, comment: "Monthly plan"),
                price: purchaseManager.monthlyPriceFormatted,
                period: String(localized: "al mes", locale: LanguageService.currentLocale, comment: "per month"),
                badge: nil
            )
        }
    }

    private func planRow(plan: Plan, title: String, price: String, period: String, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text("\(price) \(period)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 7. Botón que dice exactamente qué pasa

    private var subscribeButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Text(primaryButtonTitle)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isPurchasing || selectedProduct == nil)

            Text(priceExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var primaryButtonTitle: String {
        if let days = trialDays {
            return String(localized: "Empezar prueba de \(days) días", locale: LanguageService.currentLocale, comment: "Start free trial button")
        }
        let price = selectedPlan == .yearly ? purchaseManager.yearlyPriceFormatted : purchaseManager.monthlyPriceFormatted
        return String(localized: "Suscribirse por \(price)", locale: LanguageService.currentLocale, comment: "Subscribe button with price")
    }

    /// Renovación automática, importe y periodicidad. Legible, no en gris diminuto.
    private var priceExplanation: String {
        let price = selectedPlan == .yearly ? purchaseManager.yearlyPriceFormatted : purchaseManager.monthlyPriceFormatted
        let period = selectedPlan == .yearly
            ? String(localized: "año", locale: LanguageService.currentLocale, comment: "year")
            : String(localized: "mes", locale: LanguageService.currentLocale, comment: "month")
        if let days = trialDays {
            return String(localized: "Gratis \(days) días. Después \(price) cada \(period), con renovación automática. Cancela cuando quieras desde Ajustes.", locale: LanguageService.currentLocale, comment: "Trial terms")
        }
        return String(localized: "\(price) cada \(period), con renovación automática hasta que la canceles. Cancela cuando quieras desde Ajustes.", locale: LanguageService.currentLocale, comment: "Subscription terms")
    }

    // MARK: - 6. Términos visibles

    private var legalBlock: some View {
        VStack(spacing: 10) {
            Text(String(localized: "El pago se carga a tu cuenta de Apple al confirmar. La suscripción se renueva automáticamente salvo que la canceles al menos 24 horas antes del final del periodo. Puedes gestionarla o cancelarla en los ajustes de tu cuenta de Apple.", locale: LanguageService.currentLocale, comment: "Auto-renew legal text"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Link(String(localized: "Términos", locale: LanguageService.currentLocale, comment: "Terms link"), destination: LegalLinks.terms)
                Link(String(localized: "Privacidad", locale: LanguageService.currentLocale, comment: "Privacy link"), destination: LegalLinks.privacy)
            }
            .font(.caption)
        }
        .padding(.top, 4)
    }

    // MARK: - Compra

    private func purchase() async {
        guard let product = selectedProduct else { return }
        let ok = await purchaseManager.buy(product)
        if ok {
            // Aviso ANTES de que termine la prueba, no el mismo día.
            if let end = purchaseManager.trialEndDate(for: product) {
                await appState.localNotificationScheduler.scheduleTrialEndingReminder(trialEnds: end)
            }
            dismiss()
        } else if let err = purchaseManager.lastError {
            errorMessage = err
        }
    }

    // MARK: - Contexto: por qué se abrió el paywall

    private func highlightCard(_ feature: PremiumFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.open.fill")
                .foregroundStyle(.tint)
            Text(feature.displayName)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
