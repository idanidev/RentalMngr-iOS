import SwiftUI

struct UtilityChargesView: View {
    let vm: FinanceSummaryViewModel
    var onLoadMore: (() async -> Void)? = nil

    var body: some View {
        Group {
            if vm.utilityCharges.isEmpty {
                if vm.propertyUtilities.isEmpty {
                    EmptyStateView(
                        icon: "bolt.slash",
                        title: String(localized: "No utilities configured", locale: LanguageService.currentLocale, comment: "Empty state title when no utilities are set up"),
                        subtitle: String(localized: "Configure utility services in the property settings to start tracking payments", locale: LanguageService.currentLocale, comment: "Empty state subtitle for no utilities configured")
                    )
                } else {
                    EmptyStateView(
                        icon: "bolt.circle",
                        title: String(localized: "No utility charges", locale: LanguageService.currentLocale, comment: "Empty state title when no charges exist"),
                        subtitle: String(localized: "Utility charges will appear here once created", locale: LanguageService.currentLocale, comment: "Empty state subtitle for no utility charges")
                    )
                }
            } else {
                chargesList
            }
        }
    }

    @ViewBuilder
    private var chargesList: some View {
        VStack(spacing: 16) {
            ForEach(vm.utilityChargesByRoom, id: \.roomName) { group in
                VStack(alignment: .leading, spacing: 8) {
                    // Room/Tenant header
                    HStack {
                        Image(systemName: "door.left.hand.open")
                            .foregroundStyle(.secondary)
                        if let tenant = group.tenantName {
                            Text("\(tenant) — \(group.roomName)")
                                .font(.headline)
                                .foregroundStyle(.white)
                        } else {
                            Text(group.roomName)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    // Utility charge rows
                    VStack(spacing: 4) {
                        ForEach(group.charges) { charge in
                            UtilityChargeRow(charge: charge) {
                                Task {
                                    await vm.toggleUtilityPaid(charge)
                                }
                            }
                            .onAppear {
                                // Pagination trigger
                                if charge.id == vm.utilityCharges.last?.id {
                                    if let onLoadMore {
                                        Task { await onLoadMore() }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal)
    }
}

private struct UtilityChargeRow: View {
    let charge: UtilityCharge
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Paid toggle
            Button(action: onToggle) {
                Image(systemName: charge.paid ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(charge.paid ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Utility icon + name
            if let type = charge.type {
                Image(systemName: type.icon)
                    .foregroundStyle(type.color)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(charge.type?.displayName ?? charge.utilityType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                Text(String(localized: "Month: \(charge.month.monthYear)", locale: LanguageService.currentLocale, comment: "Utility charge month label"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if charge.amount > 0 {
                Text(charge.amount.formatted(currencyCode: "EUR"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(charge.paid ? .green : .orange)
            }
        }
        .padding(.vertical, 6)
    }
}
