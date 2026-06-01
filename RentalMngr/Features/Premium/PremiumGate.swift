import SwiftUI

/// View modifier that intercepts taps and shows the paywall if user is not premium.
/// Use on any premium-only action button.
///
/// ```swift
/// Button("Generar PDF") { ... }
///     .premiumGated(.contractPdf)
/// ```
struct PremiumGateModifier: ViewModifier {
    let feature: PremiumFeature
    @Environment(EntitlementService.self) private var entitlement
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if !entitlement.isPremium {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .padding(4)
                        .background(.thinMaterial, in: Circle())
                        .offset(x: 6, y: -6)
                        .allowsHitTesting(false)
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    if !entitlement.isPremium { showPaywall = true }
                },
                including: entitlement.isPremium ? .subviews : .gesture
            )
            .sheet(isPresented: $showPaywall) {
                PaywallView(highlightedFeature: feature)
                    .environment(entitlement)
            }
    }
}

extension View {
    /// Show a crown badge and intercept taps when user is not premium.
    /// On tap, opens the paywall sheet highlighting the requested feature.
    func premiumGated(_ feature: PremiumFeature) -> some View {
        modifier(PremiumGateModifier(feature: feature))
    }
}

/// Inline "Premium" badge, useful next to feature names in lists.
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
            Text("PRO")
        }
        .font(.caption2.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing),
                    in: Capsule())
    }
}
