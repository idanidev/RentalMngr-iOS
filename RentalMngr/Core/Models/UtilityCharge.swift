import Foundation

/// Room info embedded in utility charge from join query
struct UtilityChargeRoom: Codable, Sendable, Hashable {
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

/// A monthly utility charge for a specific room in a property.
struct UtilityCharge: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let propertyId: UUID
    let roomId: UUID
    var utilityType: String
    var amount: Decimal
    var month: Date
    var paid: Bool
    var paymentDate: Date?
    let createdAt: Date?
    // Embedded room from join query
    var room: UtilityChargeRoom?

    enum CodingKeys: String, CodingKey {
        case id, amount, month, paid, room
        case propertyId = "property_id"
        case roomId = "room_id"
        case utilityType = "utility_type"
        case paymentDate = "payment_date"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        propertyId = try container.decode(UUID.self, forKey: .propertyId)
        roomId = try container.decode(UUID.self, forKey: .roomId)
        utilityType = try container.decode(String.self, forKey: .utilityType)
        amount = try container.decode(Decimal.self, forKey: .amount)
        paid = try container.decode(Bool.self, forKey: .paid)

        // Flexible date decoding (same pattern as Income)
        month = try Self.decodeFlexibleDate(container: container, key: .month) ?? Date()
        paymentDate = try Self.decodeFlexibleDate(container: container, key: .paymentDate)
        createdAt = try Self.decodeFlexibleDate(container: container, key: .createdAt)

        // Room may come as object or array from join
        if let rooms = try? container.decode([UtilityChargeRoom].self, forKey: .room) {
            room = rooms.first
        } else {
            room = try? container.decode(UtilityChargeRoom.self, forKey: .room)
        }
    }

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
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = iso.date(from: dateString) {
                return parsed
            }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: dateString)
        }
        return nil
    }

    /// Resolved UtilityType enum.
    /// Also handles legacy Spanish DB values (e.g. "calefaccion", "electricidad").
    var type: UtilityType? {
        if let direct = UtilityType(rawValue: utilityType) { return direct }
        // Legacy Spanish values that may exist in older DB rows
        switch utilityType.lowercased() {
        case "calefaccion", "calefacción": return .heating
        case "electricidad": return .electricity
        case "agua": return .water
        case "gas": return .gas
        case "internet", "wifi": return .internet
        case "basura": return .trash
        case "comunidad", "gastos_comunidad", "community_fees": return .communityFees
        default: return nil
        }
    }

    /// Display name: room name or fallback
    var roomName: String {
        room?.name
            ?? String(
                localized: "Room", locale: LanguageService.currentLocale,
                comment: "Default room name fallback")
    }

    /// Tenant name from joined room data
    var tenantName: String? {
        room?.tenant?.fullName ?? room?.tenantName
    }
}
