import ImageIO
import PDFKit
import SwiftUI
import UIKit
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "RoomAdView")

struct RoomAdView: View {
    @Environment(AppState.self) private var appState
    let room: Room
    let propertyId: UUID

    @State private var pdfURL: URL?
    @State private var property: Property?
    @State private var isLoading = true
    @State private var errorMessage: String?
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
                VStack(spacing: 16) {
                    EmptyStateView(
                        icon: "doc.richtext",
                        title: String(localized: "Error", locale: LanguageService.currentLocale, comment: "Error title when PDF generation fails"),
                        subtitle: errorMessage ?? String(localized: "Could not generate the ad", locale: LanguageService.currentLocale, comment: "Error subtitle when PDF generation fails")
                    )
                    Button(String(localized: "Retry", locale: LanguageService.currentLocale, comment: "Button to retry loading")) {
                        Task { await generatePDF() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle(String(localized: "Ad", locale: LanguageService.currentLocale, comment: "Navigation title for room ad view"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await generatePDF()
        }
        .onDisappear {
            // Don't leave the PII-bearing PDF sitting in the temp dir after the user leaves.
            if let pdfURL { try? FileManager.default.removeItem(at: pdfURL) }
        }
    }

    // Anuncio_<TipoHabitacion>_<Direccion>_<Fecha>.pdf
    private var pdfFileName: String {
        func slug(_ s: String) -> String {
            s.replacingOccurrences(of: " ", with: "_")
                .folding(options: .diacriticInsensitive, locale: .current)
        }
        let roomLabel = room.roomType == .privateRoom ? "Habitacion" : "Zona_comun"
        let addr = slug(property?.address ?? "")
        let dateStr = Date().formatted(.iso8601.year().month().day())
        let parts = ["Anuncio", roomLabel, addr.isEmpty ? nil : addr, dateStr].compactMap { $0 }
        return parts.joined(separator: "_") + ".pdf"
    }

    private func generatePDF() async {
        isLoading = true
        errorMessage = nil
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
            let roomImages = await downloadImages(from: room.photos)

            // Download common room photos
            var commonRoomImages: [String: [UIImage]] = [:]
            for commonRoom in commonRooms where !commonRoom.photos.isEmpty {
                let images = await downloadImages(from: Array(commonRoom.photos.prefix(2)))
                if !images.isEmpty {
                    commonRoomImages[commonRoom.id.uuidString] = images
                }
            }

            loadingMessage = String(localized: "Generating PDF...", locale: LanguageService.currentLocale, comment: "Loading message while generating PDF")
            let utilities = (try? await appState.utilityService.fetchPropertyUtilities(propertyId: propertyId)) ?? []
            let communityUtility = utilities.first { $0.type == .communityFees }
            // Contact: prefer the landlord phone, fall back to the email so the flyer always
            // has a way to reach the owner.
            let landlord = try? await appState.userProfileService.getLandlordProfile()
            let contact: String? = {
                if let phone = landlord?.phone, !phone.isEmpty { return phone }
                if let email = landlord?.email, !email.isEmpty { return email }
                return nil
            }()
            let generator = PDFGenerator()
            let pdfData = await generator.generateRoomAd(
                room: room,
                property: property,
                commonRooms: commonRooms,
                depositAmount: nil,
                ownerContact: contact,
                roomImages: roomImages,
                commonRoomImages: commonRoomImages,
                communityFeesIncludes: communityUtility?.includedServices ?? [],
                communityFeesAmount: communityUtility?.monthlyAmount
            )

            // Write to named temp file so ShareLink uses correct filename and type
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(pdfFileName)
            try pdfData.write(to: url)
            self.pdfURL = url
        } catch {
            logger.error("Room ad generation failed: \(error.localizedDescription)")
            errorMessage = error.safeUserMessage
        }
        isLoading = false
    }

    private func downloadImages(from paths: [String]) async -> [UIImage] {
        var images: [UIImage] = []
        for path in paths.prefix(6) {
            do {
                let url = try await SignedURLCache.shared.url(
                    bucket: SupabaseConfig.storageBucket, path: path)
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = downsampledImage(from: data) {
                    images.append(image)
                }
            } catch {
                logger.error("Ad image download failed (\(path)): \(error.localizedDescription)")
                continue
            }
        }
        return images
    }

    /// Decode an image at a reduced pixel size so embedding it in the PDF doesn't spike
    /// memory or bloat the file (camera photos are ~4000px; the ad draws them at ~250pt).
    private func downsampledImage(from data: Data, maxPixel: CGFloat = 1400) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return UIImage(data: data) }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return UIImage(data: data) }
        return UIImage(cgImage: cgImage)
    }
}
