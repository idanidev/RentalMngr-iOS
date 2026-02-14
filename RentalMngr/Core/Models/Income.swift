import Foundation

/// Tenant info embedded in income from nested join: tenant:tenant_id(full_name)
struct IncomeTenant: Codable, Sendable, Hashable {
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}

/// Room info embedded in income from join: room:room_id(id, name, tenant_name, tenant:tenant_id(full_name))
struct IncomeRoom: Codable, Sendable, Hashable {
    let id: UUID
    let name: String
    let tenantName: String?
    var tenant: IncomeTenant?

    enum CodingKeys: String, CodingKey {
        case id, name, tenant
        case tenantName = "tenant_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tenantName = try container.decodeIfPresent(String.self, forKey: .tenantName)
        // Supabase may return tenant as array or object
        if let tenants = try? container.decode([IncomeTenant].self, forKey: .tenant) {
            tenant = tenants.first
        } else {
            tenant = try? container.decode(IncomeTenant.self, forKey: .tenant)
        }
    }
}

struct Income: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    let roomId: UUID
    var amount: Decimal
    var month: Date
    var paid: Bool
    var paymentDate: Date?
    var notes: String?
    let createdAt: Date?
    var updatedAt: Date?
    // Embedded room from join query
    var room: IncomeRoom?

    enum CodingKeys: String, CodingKey {
        case id, amount, month, paid, notes, room
        case propertyId = "property_id"
        case roomId = "room_id"
        case paymentDate = "payment_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Custom decoder to handle date-only strings from Supabase (e.g. "2026-02-01")
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        propertyId = try container.decode(UUID.self, forKey: .propertyId)
        roomId = try container.decode(UUID.self, forKey: .roomId)
        amount = try container.decode(Decimal.self, forKey: .amount)
        paid = try container.decode(Bool.self, forKey: .paid)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // month may come as "2026-02-01" (date only) from Supabase
        month = try Self.decodeFlexibleDate(container: container, key: .month) ?? Date()
        paymentDate = try Self.decodeFlexibleDate(container: container, key: .paymentDate)
        createdAt = try Self.decodeFlexibleDate(container: container, key: .createdAt)
        updatedAt = try Self.decodeFlexibleDate(container: container, key: .updatedAt)

        // Room may come as object or array from join
        if let rooms = try? container.decode([IncomeRoom].self, forKey: .room) {
            room = rooms.first
        } else {
            room = try? container.decode(IncomeRoom.self, forKey: .room)
        }
    }

    /// Try standard Date decoding, then fall back to date-only string
    private static func decodeFlexibleDate(
        container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys
    ) throws -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        if let dateString = try? container.decode(String.self, forKey: key) {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.locale = Locale(identifier: "en_US_POSIX")
            if let parsed = df.date(from: dateString) {
                return parsed
            }
            // Try ISO8601 with fractional seconds
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = iso.date(from: dateString) {
                return parsed
            }
            // Try ISO8601 without fractional seconds
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: dateString)
        }
        return nil
    }

    /// Display name: room name or fallback
    var roomName: String {
        room?.name ?? "Habitación"
    }

    /// Tenant name: prefer joined tenant full_name, fallback to denormalized tenant_name
    var tenantName: String? {
        room?.tenant?.fullName ?? room?.tenantName
    }
}
