import PDFKit
import SwiftUI
import UIKit

struct RoomAdView: View {
    @Environment(AppState.self) private var appState
    let room: Room
    let propertyId: UUID

    @State private var pdfURL: URL?
    @State private var property: Property?
    @State private var isLoading = true
    @State private var loadingMessage = String(localized: "Loading data...", locale: LanguageService.currentLocale, comment: "Loading message while fetching room ad data")

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: loadingMessage)
            } else if let pdfURL {
                VStack {
                    PDFKitView(url: pdfURL)

                    ShareLink(
                        item: pdfURL,
                        preview: SharePreview(
                            String(localized: "Ad - \(room.name)", locale: LanguageService.currentLocale, comment: "Share preview title for room ad PDF"), image: Image(systemName: "doc.richtext"))
                    ) {
                        Label(String(localized: "Share ad", locale: LanguageService.currentLocale, comment: "Button to share the room ad"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            } else {
                EmptyStateView(
                    icon: "doc.richtext",
                    title: String(localized: "Error", locale: LanguageService.currentLocale, comment: "Error title when PDF generation fails"),
                    subtitle: String(localized: "Could not generate the ad", locale: LanguageService.currentLocale, comment: "Error subtitle when PDF generation fails")
                )
            }
        }
        .navigationTitle(String(localized: "Ad", locale: LanguageService.currentLocale, comment: "Navigation title for room ad view"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await generatePDF()
        }
    }

    // Anuncio_<NombrePropiedad>_<NombreHabitacion>_<Fecha>.pdf
    private var pdfFileName: String {
        let safeProp = (property?.name ?? "Property")
            .replacingOccurrences(of: " ", with: "_")
            .folding(options: .diacriticInsensitive, locale: .current)
        let safeRoom = room.name
            .replacingOccurrences(of: " ", with: "_")
            .folding(options: .diacriticInsensitive, locale: .current)
        let dateStr = Date().formatted(.iso8601.year().month().day())
        return "Anuncio_\(safeProp)_\(safeRoom)_\(dateStr).pdf"
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
            loadingMessage = String(localized: "Downloading photos...", locale: LanguageService.currentLocale, comment: "Loading message while downloading photos")
            let roomImages = await downloadImages(from: room.photoUrls)

            // Download common room photos
            var commonRoomImages: [String: [UIImage]] = [:]
            for commonRoom in commonRooms where !commonRoom.photos.isEmpty {
                let images = await downloadImages(from: Array(commonRoom.photoUrls.prefix(2)))
                if !images.isEmpty {
                    commonRoomImages[commonRoom.id.uuidString] = images
                }
            }

            loadingMessage = String(localized: "Generating PDF...", locale: LanguageService.currentLocale, comment: "Loading message while generating PDF")
            let generator = PDFGenerator()
            let pdfData = await generator.generateRoomAd(
                room: room,
                property: property,
                commonRooms: commonRooms,
                depositAmount: room.monthlyRent,
                roomImages: roomImages,
                commonRoomImages: commonRoomImages
            )

            // Write to named temp file so ShareLink uses correct filename and type
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(pdfFileName)
            try pdfData.write(to: url)
            self.pdfURL = url
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
