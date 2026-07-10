import PDFKit
import SwiftUI

/// PDF preview of a property's contract template. Uses the landlord's REAL
/// profile + the real property + the real custom variables, with SAMPLE tenant
/// data (name, DNI, dates, rent, deposit) so a landlord can check the final
/// look of the contract before assigning it to a tenant.
struct ContractPreviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    /// Real property to preview against. When nil (e.g. the global template editor)
    /// a sample property is used.
    var property: Property?
    /// Template text to preview (e.g. unsaved editor text). When nil, the generator
    /// resolves the property/global template as usual.
    var templateOverride: String?

    @State private var pdfURL: URL?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingView(
                    message: String(localized: "Generando vista previa…",
                        locale: LanguageService.currentLocale, comment: "Loading message for contract preview"))
            } else if let pdfURL {
                VStack(spacing: 0) {
                    PDFKitView(url: pdfURL)

                    Text(String(localized: "Vista previa con datos de ejemplo. El inquilino, fechas e importes reales se rellenan al generar el contrato desde el inquilino.",
                        locale: LanguageService.currentLocale, comment: "Contract preview disclaimer"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                }
            } else {
                EmptyStateView(
                    icon: "doc.text",
                    title: "Error",
                    subtitle: String(localized: "No se pudo generar la vista previa",
                        locale: LanguageService.currentLocale, comment: "Error generating contract preview")
                )
            }
        }
        .navigationTitle(String(localized: "Vista previa del contrato",
            locale: LanguageService.currentLocale, comment: "Contract preview navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cerrar", locale: LanguageService.currentLocale, comment: "Close button")) {
                    dismiss()
                }
            }
        }
        .task { await generate() }
        .onDisappear {
            if let pdfURL { try? FileManager.default.removeItem(at: pdfURL) }
        }
    }

    private func generate() async {
        let prop = property ?? Self.samplePreviewProperty()
        let landlord = (try? await appState.userProfileService.getLandlordProfile()) ?? .empty
        let customVars = (try? await ContractVariableService().fetchVariables()) ?? []
        var communityFees: [String] = []
        var communityFeesAmount: Decimal? = nil
        if let property {
            let utilities = (try? await appState.utilityService.fetchPropertyUtilities(propertyId: property.id)) ?? []
            let communityUtility = utilities.first { $0.type == .communityFees }
            communityFees = communityUtility?.includedServices ?? []
            communityFeesAmount = communityUtility?.monthlyAmount
        }

        let start = Date()
        let end = Calendar.current.date(byAdding: .month, value: 6, to: start)

        let sampleRoom = Room(
            id: UUID(),
            propertyId: prop.id,
            tenantId: nil,
            name: String(localized: "Habitación de ejemplo",
                locale: LanguageService.currentLocale, comment: "Sample room name for contract preview"),
            monthlyRent: 350,
            sizeSqm: nil,
            occupied: true,
            tenantName: "Ana García López",
            notes: nil,
            roomType: .privateRoom,
            photos: [],
            createdAt: nil,
            updatedAt: nil
        )

        let sampleTenant = Tenant(
            id: UUID(),
            propertyId: prop.id,
            fullName: "Ana García López",
            dni: "12345678A",
            contractStartDate: start,
            contractEndDate: end,
            depositAmount: 350,
            currentAddress: prop.address,
            active: true
        )

        do {
            let data = try await PDFGenerator().generateContract(
                tenant: sampleTenant,
                room: sampleRoom,
                property: prop,
                landlord: landlord,
                template: templateOverride,
                customVariables: customVars,
                communityFeesIncludes: communityFees,
                communityFeesAmount: communityFeesAmount
            )
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Vista_previa_contrato.pdf")
            try data.write(to: url)
            pdfURL = url
        } catch {
            // leaves pdfURL nil → error state
        }
        isLoading = false
    }

    private static func samplePreviewProperty() -> Property {
        Property(
            id: UUID(),
            name: "Vivienda de ejemplo",
            address: "Calle de ejemplo 1, Madrid",
            description: nil,
            ownerId: UUID(),
            createdAt: Date(),
            updatedAt: nil,
            contractTemplate: nil,
            rooms: nil
        )
    }
}
