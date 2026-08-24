import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContractView: View {
    @Environment(AppState.self) private var appState
    let tenant: Tenant
    let propertyId: UUID

    @State private var pdfURL: URL?
    @State private var property: Property?
    @State private var rooms: [Room] = []
    @State private var isLoading = true
    @State private var showPaywall = false

    var body: some View {
        Group {
            if isLoading {
                LoadingView(
                    message: String(localized: "Generating contract...",
                        locale: LanguageService.currentLocale, comment: "Loading message while generating PDF contract"))
            } else if let pdfURL {
                VStack {
                    PDFKitView(url: pdfURL)

                    ShareLink(
                        item: pdfURL,
                        preview: SharePreview(
                            String(localized: "Contract - \(tenant.fullName)",
                                locale: LanguageService.currentLocale, comment: "Share preview title for tenant contract"),
                            image: Image(systemName: "doc.text"))
                    ) {
                        Label(
                            String(localized: "Share contract",
                                locale: LanguageService.currentLocale, comment: "Button label to share contract PDF"),
                            systemImage: "square.and.arrow.up"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            } else {
                EmptyStateView(
                    icon: "doc.text",
                    title: "Error",
                    subtitle: String(localized: "Could not generate the contract",
                        locale: LanguageService.currentLocale, comment: "Error message when contract PDF generation fails")
                )
            }
        }
        .navigationTitle(
            String(localized: "Contract", locale: LanguageService.currentLocale, comment: "Navigation title for contract view")
        )
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await generatePDF()
        }
        .onDisappear {
            // The contract PDF embeds tenant + landlord DNI/names — don't leave it in temp.
            if let pdfURL { try? FileManager.default.removeItem(at: pdfURL) }
        }
        .sheet(isPresented: $showPaywall, onDismiss: { /* user dismissed paywall */ }) {
            PaywallView(highlightedFeature: .contractPdf)
                .environment(appState.entitlementService)
        }
    }

    // MARK: - PDF file name (mirrors web: Contrato_Habitación_Nombre_Apellido_YYYY-MM-DD.pdf)

    private var pdfFileName: String {
        let safeName = tenant.fullName
            .replacingOccurrences(of: " ", with: "_")
            .folding(options: .diacriticInsensitive, locale: .current) // strip accents
        let dateStr = Date().formatted(.iso8601.year().month().day())
        return "Contrato_Habitacion_\(safeName)_\(dateStr).pdf"
    }

    private func generatePDF() async {
        // Premium gate: contract PDF is a paid feature
        guard appState.entitlementService.isPremium else {
            isLoading = false
            showPaywall = true
            return
        }
        do {
            property = try await appState.propertyService.fetchProperty(id: propertyId)
            rooms = try await appState.roomService.fetchRooms(propertyId: propertyId)

            guard let property else {
                isLoading = false
                return
            }

            // Use the tenant's assigned room. If the tenant isn't assigned to any
            // room, a blank room leaves the room/rent fields empty in the contract
            // (a fill-in line) instead of borrowing the first room's data.
            let room = rooms.first { $0.tenantId == tenant.id }
                ?? Room(
                    id: UUID(), propertyId: property.id, tenantId: tenant.id,
                    name: "", monthlyRent: 0, sizeSqm: nil, occupied: false,
                    tenantName: tenant.fullName, notes: nil, roomType: .privateRoom,
                    photos: [], createdAt: nil, updatedAt: nil)

            let generator = PDFGenerator()
            let landlord = (try? await appState.userProfileService.getLandlordProfile()) ?? .empty
            let customVars = (try? await ContractVariableService().fetchVariables()) ?? []
            let utilities = (try? await appState.utilityService.fetchPropertyUtilities(propertyId: propertyId)) ?? []
            let communityUtility = utilities.first { $0.type == .communityFees }
            let pdfData = try await generator.generateContract(
                tenant: tenant, room: room, property: property, landlord: landlord,
                customVariables: customVars,
                communityFeesIncludes: communityUtility?.includedServices ?? [],
                communityFeesAmount: communityUtility?.monthlyAmount)

            // Write to a named temp file so ShareLink knows the filename and type
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(pdfFileName)
            try pdfData.write(to: url)
            pdfURL = url
            appState.reviewPrompter.registerSuccess()
        } catch {
            // Failed to load data — isLoading = false shows error state
        }
        isLoading = false
    }
}


// MARK: - PDFKit UIViewRepresentable

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}
