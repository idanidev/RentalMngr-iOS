import Foundation

enum RoomType: String, Codable, Sendable, CaseIterable {
    case privateRoom = "private"
    case common = "common"

    var displayName: String {
        switch self {
        case .privateRoom: String(localized: "room.type.private", defaultValue: "Private room", locale: LanguageService.currentLocale)
        case .common: String(localized: "room.type.common", defaultValue: "Common area", locale: LanguageService.currentLocale)
        }
    }
}

struct Room: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    var tenantId: UUID?
    var name: String
    var monthlyRent: Decimal
    var sizeSqm: Decimal?
    var occupied: Bool
    var tenantName: String?
    var notes: String?
    var roomType: RoomType
    var photos: [String]
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, occupied, photos, notes
        case propertyId = "property_id"
        case tenantId = "tenant_id"
        case monthlyRent = "monthly_rent"
        case sizeSqm = "size_sqm"
        case tenantName = "tenant_name"
        case roomType = "room_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Convert storage paths to public URLs (full resolution)
    var photoUrls: [URL] {
        photos.compactMap { path in
            URL(string: "\(SupabaseConfig.url.absoluteString)/storage/v1/object/public/\(SupabaseConfig.storageBucket)/\(path)")
        }
    }

    /// Thumbnail URLs using Supabase image transforms.
    /// - Parameters:
    ///   - width: Target width in logical points (will be served at this pixel size).
    ///   - height: Target height in logical points.
    ///   - quality: JPEG quality 1–100 (default 80).
    func thumbnailUrls(width: Int = 800, height: Int = 600, quality: Int = 80) -> [URL] {
        photos.compactMap { path in
            URL(string: "\(SupabaseConfig.url.absoluteString)/storage/v1/render/image/public/\(SupabaseConfig.storageBucket)/\(path)?width=\(width)&height=\(height)&resize=cover&quality=\(quality)")
        }
    }

    /// Convenience: thumbnail URLs sized for list card hero images (~400pt wide @2x).
    var listThumbnailUrls: [URL] { thumbnailUrls(width: 800, height: 600, quality: 80) }

    /// Convenience: thumbnail URLs sized for small strips (detail view horizontal scroll).
    var stripThumbnailUrls: [URL] { thumbnailUrls(width: 300, height: 225, quality: 75) }
}
