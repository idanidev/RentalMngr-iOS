import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContractView: View {
    @Environment(AppState.self) private var appState
    let tenant: Tenant
    let propertyId: UUID

    @State private var pdfData: Data?
    @State private var property: Property?
    @State private var rooms: [Room] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Generando contrato...")
            } else if let pdfData {
                VStack {
                    PDFKitView(data: pdfData)

                    ShareLink(
                        item: pdfData,
                        preview: SharePreview(
                            "Contrato - \(tenant.fullName)", image: Image(systemName: "doc.text"))
                    ) {
                        Label("Compartir contrato", systemImage: "square.and.arrow.up")
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
                    subtitle: "No se pudo generar el contrato"
                )
            }
        }
        .navigationTitle("Contrato")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await generatePDF()
        }
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
            pdfData = generator.generateContract(tenant: tenant, room: room, property: property)
        } catch {
            // Failed to load data
        }
        isLoading = false
    }
}

// MARK: - PDFKit UIViewRepresentable

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            uiView.document = document
        }
    }
}
