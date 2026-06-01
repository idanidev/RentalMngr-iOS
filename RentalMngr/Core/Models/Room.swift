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

    /// Public URL for a stored photo path. The path is used verbatim: web-app rows
    /// store keys like `room-photos/{prop}/{room}/file.jpeg` and iOS rows store
    /// `{room}/file.jpg` — both are valid object keys inside the bucket.
    private static func publicURL(for path: String) -> URL? {
        URL(string: "\(SupabaseConfig.url.absoluteString)/storage/v1/object/public/\(SupabaseConfig.storageBucket)/\(path)")
    }

    /// Convert storage paths to public URLs (full resolution)
    var photoUrls: [URL] {
        photos.compactMap { Room.publicURL(for: $0) }
    }

    /// Thumbnail URLs using Supabase image transforms.
    /// - Parameters:
    ///   - width: Target width in logical points (will be served at this pixel size).
    ///   - height: Target height in logical points.
    ///   - quality: JPEG quality 1–100 (default 80).
    func thumbnailUrls(width: Int = 800, height: Int = 600, quality: Int = 80) -> [URL] {
        // NOTE: Supabase image transforms (`/render/image`) require a Pro plan and
        // return 403 on free tier. Serve full-res objects instead; AsyncImageView
        // downsizes locally via `targetSize`.
        photoUrls
    }

    /// Convenience: thumbnail URLs sized for list card hero images (~400pt wide @2x).
    var listThumbnailUrls: [URL] { thumbnailUrls(width: 800, height: 600, quality: 80) }

    /// Convenience: thumbnail URLs sized for small strips (detail view horizontal scroll).
    var stripThumbnailUrls: [URL] { thumbnailUrls(width: 300, height: 225, quality: 75) }
}

// MARK: - Decoding (tolerant of legacy web-app rows)

extension Room {
    /// Custom decoder placed in an extension so the synthesized memberwise
    /// initializer (used by `RoomFormViewModel`) is preserved.
    ///
    /// `photos` may arrive as a native JSON array (iOS-created rooms) or as a
    /// JSON-encoded string (legacy web-app rows). Accept both formats.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        propertyId = try c.decode(UUID.self, forKey: .propertyId)
        tenantId = try c.decodeIfPresent(UUID.self, forKey: .tenantId)
        name = try c.decode(String.self, forKey: .name)
        monthlyRent = try c.decode(Decimal.self, forKey: .monthlyRent)
        sizeSqm = try c.decodeIfPresent(Decimal.self, forKey: .sizeSqm)
        occupied = try c.decodeIfPresent(Bool.self, forKey: .occupied) ?? false
        tenantName = try c.decodeIfPresent(String.self, forKey: .tenantName)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        roomType = try c.decodeIfPresent(RoomType.self, forKey: .roomType) ?? .privateRoom
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)

        if let arr = try? c.decode([String].self, forKey: .photos) {
            photos = arr
        } else if let raw = try? c.decode(String.self, forKey: .photos),
                  let data = raw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) {
            photos = arr
        } else {
            photos = []
        }
    }
}
