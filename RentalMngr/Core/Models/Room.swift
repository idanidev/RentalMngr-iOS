import Foundation

enum RoomType: String, Codable, Sendable, CaseIterable {
    case privateRoom = "private"
    case common = "common"
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

    /// Convert storage paths to public URLs
    /// Matches webapp: supabase.storage.from('room-photos').getPublicUrl(photoPath)
    var photoUrls: [URL] {
        photos.compactMap { path in
            URL(string: "\(SupabaseConfig.url.absoluteString)/storage/v1/object/public/\(SupabaseConfig.storageBucket)/\(path)")
        }
    }
}
