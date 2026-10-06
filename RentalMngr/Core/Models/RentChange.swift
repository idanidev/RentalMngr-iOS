import Foundation

/// Una subida (o bajada) de renta de un inquilino, tal como quedó registrada.
///
/// Hasta que existió esto, la renta solo era el valor actual: al cambiarla se
/// pisaba la anterior y no quedaba rastro (#24).
struct RentChange: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let tenantId: UUID
    let propertyId: UUID
    let roomId: UUID?
    /// Nula si el inquilino no tenía renta registrada antes del cambio.
    let previousAmount: Decimal?
    let newAmount: Decimal
    /// Desde cuándo rige la renta nueva.
    let effectiveDate: Date
    let note: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, note
        case tenantId = "tenant_id"
        case propertyId = "property_id"
        case roomId = "room_id"
        case previousAmount = "previous_amount"
        case newAmount = "new_amount"
        case effectiveDate = "effective_date"
        case createdAt = "created_at"
    }

    init(
        id: UUID, tenantId: UUID, propertyId: UUID, roomId: UUID? = nil,
        previousAmount: Decimal?, newAmount: Decimal, effectiveDate: Date,
        note: String? = nil, createdAt: Date? = nil
    ) {
        self.id = id
        self.tenantId = tenantId
        self.propertyId = propertyId
        self.roomId = roomId
        self.previousAmount = previousAmount
        self.newAmount = newAmount
        self.effectiveDate = effectiveDate
        self.note = note
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        tenantId = try c.decode(UUID.self, forKey: .tenantId)
        propertyId = try c.decode(UUID.self, forKey: .propertyId)
        roomId = try c.decodeIfPresent(UUID.self, forKey: .roomId)
        previousAmount = try c.decodeIfPresent(Decimal.self, forKey: .previousAmount)
        newAmount = try c.decode(Decimal.self, forKey: .newAmount)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
        // `effective_date` es de tipo date: llega como "2026-11-01", sin hora.
        if let date = try? c.decode(Date.self, forKey: .effectiveDate) {
            effectiveDate = date
        } else {
            let texto = try c.decode(String.self, forKey: .effectiveDate)
            guard let date = Self.dayFormatter.date(from: texto) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .effectiveDate, in: c,
                    debugDescription: "Fecha sin formato yyyy-MM-dd: \(texto)")
            }
            effectiveDate = date
        }
    }

    /// Cuánto ha cambiado, en porcentaje. Nulo si no había renta anterior con la
    /// que comparar.
    var percentChange: Double? {
        guard let anterior = previousAmount, anterior > 0 else { return nil }
        return NSDecimalNumber(decimal: (newAmount - anterior) / anterior * 100).doubleValue
    }

    /// Para mandar fechas de solo día a la base. Se usa el calendario local para
    /// que "1 de noviembre" no se convierta en el 31 de octubre al pasar a UTC.
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// Lo que se escribe en el formulario de "Registrar subida", antes de mandarlo.
///
/// Separado de la vista para poder probar las reglas sin pantallas.
struct RentChangeDraft: Sendable {
    var amountText: String = ""
    var effectiveDate: Date = Date()
    var note: String = ""

    enum Problem: Equatable {
        case notANumber
        case notPositive
        case sameAsCurrent
    }

    var amount: Decimal? { Decimal.fromUserInput(amountText) }

    /// Qué impide guardarlo, si algo lo impide.
    func problem(currentRent: Decimal?) -> Problem? {
        guard let amount else { return .notANumber }
        guard amount > 0 else { return .notPositive }
        if let currentRent, currentRent == amount { return .sameAsCurrent }
        return nil
    }
}
