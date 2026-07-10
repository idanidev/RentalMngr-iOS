import Foundation

struct ContractVariable: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var label: String
    var defaultValue: String
    let userId: String?
    let createdAt: Date?

    /// The placeholder key used in templates: {{name}}
    var templateKey: String { "{{\(name)}}" }

    enum CodingKeys: String, CodingKey {
        case id, name, label
        case defaultValue = "default_value"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

// MARK: - Built-in variables (read-only, not stored in DB)

extension ContractVariable {
    static let builtIn: [(key: String, icon: String, label: String)] = [
        ("{{tenant_name}}", "person", "Nombre inquilino"),
        ("{{tenant_dni}}", "creditcard", "DNI inquilino"),
        ("{{tenant_address}}", "house", "Domicilio inquilino"),
        ("{{landlord_name}}", "person.badge.key", "Nombre arrendador"),
        ("{{landlord_dni}}", "creditcard.fill", "DNI arrendador"),
        ("{{property_address}}", "mappin", "Dirección inmueble"),
        ("{{room_name}}", "bed.double", "Habitación"),
        ("{{start_date}}", "calendar", "Inicio contrato"),
        ("{{end_date}}", "calendar.badge.checkmark", "Fin contrato"),
        ("{{rent}}", "eurosign", "Renta mensual"),
        ("{{gastos_comunes}}", "building.2", "Gastos comunes"),
        ("{{total_mensual}}", "sum", "Total mensual"),
        ("{{community_fees_includes}}", "list.bullet", "Gastos comunes incluyen"),
        ("{{deposit}}", "banknote", "Depósito"),
        ("{{deposit_words}}", "textformat.123", "Depósito en letras"),
        ("{{date}}", "clock", "Fecha actual"),
    ]
}
