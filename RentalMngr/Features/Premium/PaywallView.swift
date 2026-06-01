import Auth
import Supabase
import SwiftUI

struct PaywallView: View {
    let highlightedFeature: PremiumFeature?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(EntitlementService.self) private var entitlement
    @State private var errorMessage: String?

    private var purchaseManager: PurchaseManager { appState.purchaseManager }
    private var isPurchasing: Bool { purchaseManager.purchaseInProgress }

    init(highlightedFeature: PremiumFeature? = nil) {
        self.highlightedFeature = highlightedFeature
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    if let f = highlightedFeature { highlightCard(f) }
                    benefitsList
                    pricing
                    Spacer(minLength: 16)
                }
                .padding(20)
            }
            .navigationTitle("RentalMngr Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .errorAlert($errorMessage)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("Desbloquea todo el potencial")
                .font(.title2).bold()
                .multilineTextAlignment(.center)
            Text("Sin límites. Funciones avanzadas. Cancela cuando quieras.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func highlightCard(_ f: PremiumFeature) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Función premium", systemImage: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text(f.displayName)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefit("Propiedades y habitaciones ilimitadas", "house.fill")
            benefit("Generar contratos en PDF", "doc.text.fill")
            benefit("Generar anuncios de habitaciones", "megaphone.fill")
            benefit("Compartir propiedades con colaboradores", "person.2.fill")
            benefit("Variables y plantillas personalizadas", "chevron.left.forwardslash.chevron.right")
            benefit("Documentos ilimitados", "folder.fill")
            benefit("Histórico financiero completo", "chart.line.uptrend.xyaxis")
            benefit("Exportar datos (CSV, PDF)", "square.and.arrow.up.fill")
            benefit("Sin marca de agua en PDFs", "checkmark.seal.fill")
            benefit("Soporte prioritario", "envelope.fill")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(width: 22)
            Text(text).font(.subheadline)
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
        }
    }

    private var pricing: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(purchaseManager.monthlyPriceFormatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("al mes · cancela cuando quieras")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            Button {
                Task { await purchase() }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                        Text("Hacerse Premium")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .disabled(isPurchasing || purchaseManager.monthlyPremium == nil)

            Button("Restaurar compra") { Task { await restore() } }
                .font(.footnote)
                .disabled(isPurchasing)

            if let pmErr = purchaseManager.lastError {
                Text(pmErr)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("La suscripción se renueva automáticamente. Puedes cancelar en cualquier momento desde Ajustes de tu Apple ID.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .task {
            // Ensure products are loaded when paywall opens (covers case of no login refresh yet)
            if purchaseManager.products.isEmpty {
                await purchaseManager.loadProducts()
            }
        }
    }

    // MARK: - Purchase actions

    private func purchase() async {
        let success = await purchaseManager.buyMonthlyPremium()
        if success {
            // Refresh entitlement is already triggered inside PurchaseManager.syncToServer.
            // Wait briefly to ensure UI shows new tier, then dismiss.
            try? await Task.sleep(for: .milliseconds(400))
            dismiss()
        }
    }

    private func restore() async {
        await purchaseManager.restorePurchases()
        if let userId = SupabaseService.shared.client.auth.currentUser?.id {
            await entitlement.refresh(userId: userId)
        }
        if entitlement.isPremium {
            try? await Task.sleep(for: .milliseconds(400))
            dismiss()
        }
    }
}
