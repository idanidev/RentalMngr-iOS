import PDFKit
import SwiftUI
import UIKit

struct RoomAdView: View {
    @Environment(AppState.self) private var appState
    let room: Room
    let propertyId: UUID

    @State private var pdfData: Data?
    @State private var property: Property?
    @State private var isLoading = true
    @State private var loadingMessage = "Cargando datos..."

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: loadingMessage)
            } else if let pdfData {
                VStack {
                    PDFKitView(data: pdfData)

                    ShareLink(
                        item: pdfData,
                        preview: SharePreview(
                            "Anuncio - \(room.name)", image: Image(systemName: "doc.richtext"))
                    ) {
                        Label("Compartir anuncio", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            } else {
                EmptyStateView(
                    icon: "doc.richtext",
                    title: "Error",
                    subtitle: "No se pudo generar el anuncio"
                )
            }
        }
        .navigationTitle("Anuncio")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await generatePDF()
        }
    }

    private func generatePDF() async {
        do {
            property = try await appState.propertyService.fetchProperty(id: propertyId)
            let allRooms = try await appState.roomService.fetchRooms(propertyId: propertyId)
            let commonRooms = allRooms.filter { $0.roomType == .common }

            guard let property else {
                isLoading = false
                return
            }

            // Download room photos
            loadingMessage = "Descargando fotos..."
            let roomImages = await downloadImages(from: room.photoUrls)

            // Download common room photos
            var commonRoomImages: [String: [UIImage]] = [:]
            for commonRoom in commonRooms where !commonRoom.photos.isEmpty {
                let images = await downloadImages(from: Array(commonRoom.photoUrls.prefix(2)))
                if !images.isEmpty {
                    commonRoomImages[commonRoom.id.uuidString] = images
                }
            }

            loadingMessage = "Generando PDF..."
            let generator = PDFGenerator()
            pdfData = generator.generateRoomAd(
                room: room,
                property: property,
                commonRooms: commonRooms,
                depositAmount: room.monthlyRent,
                roomImages: roomImages,
                commonRoomImages: commonRoomImages
            )
        } catch {
            // Failed to load data
        }
        isLoading = false
    }

    private func downloadImages(from urls: [URL]) async -> [UIImage] {
        var images: [UIImage] = []
        for url in urls.prefix(6) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    images.append(image)
                }
            } catch {
                continue
            }
        }
        return images
    }
}
