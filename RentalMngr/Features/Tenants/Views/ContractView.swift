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
        do {
            property = try await appState.propertyService.fetchProperty(id: propertyId)
            rooms = try await appState.roomService.fetchRooms(propertyId: propertyId)

            // Find the tenant's room
            let tenantRoom =
                rooms.first { $0.tenantId == tenant.id }
                ?? rooms.first  // Fallback to first room

            guard let property, let room = tenantRoom else {
                isLoading = false
                return
            }

            let generator = PDFGenerator()
            let landlord = (try? await appState.userProfileService.getLandlordProfile()) ?? .empty
            let pdfData = try await generator.generateContract(
                tenant: tenant, room: room, property: property, landlord: landlord)

            // Write to a named temp file so ShareLink knows the filename and type
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(pdfFileName)
            try pdfData.write(to: url)
            pdfURL = url
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
