import Foundation
import Supabase

/// Qué se lleva por delante un borrado.
///
/// Las tablas cuelgan de `properties` y `rooms` con `ON DELETE CASCADE`: borrar
/// una habitación borra también sus ingresos, sus cargos de suministros y su
/// inventario, y no hay papelera ni backups en el plan actual. Un "¿seguro?"
/// genérico no da información para decidir; "se borrarán 24 ingresos" sí.
///
/// Se consulta solo al pulsar borrar, con peticiones HEAD (`count: .exact`, sin
/// traer filas). Si falla el recuento, la confirmación sigue apareciendo con el
/// texto genérico: nunca se borra sin preguntar.
struct DeletionImpact: Sendable {
    /// Etiquetas ya montadas, en orden de importancia: ["24 ingresos", "8 objetos del inventario"].
    let items: [String]

    var isEmpty: Bool { items.isEmpty }

    /// "24 ingresos, 5 cargos de suministros y 8 objetos del inventario"
    var sentence: String {
        guard let last = items.last else { return "" }
        guard items.count > 1 else { return last }
        let head = items.dropLast().joined(separator: ", ")
        let and = String(localized: "y", locale: LanguageService.currentLocale, comment: "List conjunction")
        return "\(head) \(and) \(last)"
    }
}

enum DeletionImpactService {
    private static var client: SupabaseClient { SupabaseService.shared.client }

    private static func count(_ table: String, column: String, equals id: UUID) async -> Int {
        let response = try? await client
            .from(table)
            .select("id", head: true, count: .exact)
            .eq(column, value: id)
            .execute()
        return response?.count ?? 0
    }

    /// Lo que desaparece al borrar una habitación.
    ///
    /// `expenses.room_id` es `ON DELETE SET NULL`, así que los gastos NO se
    /// borran: quedan asociados a la propiedad. No se mencionan para no asustar
    /// con algo que no pasa.
    static func forRoom(_ roomId: UUID) async -> DeletionImpact {
        async let income = count(SupabaseTable.income, column: "room_id", equals: roomId)
        async let charges = count(SupabaseTable.utilityCharges, column: "room_id", equals: roomId)
        async let inventory = count(SupabaseTable.inventoryItems, column: "room_id", equals: roomId)

        var items: [String] = []
        let (i, c, inv) = await (income, charges, inventory)
        if i > 0 { items.append(String(localized: "\(i) ingresos registrados", locale: LanguageService.currentLocale, comment: "Deletion impact: income records")) }
        if c > 0 { items.append(String(localized: "\(c) cargos de suministros", locale: LanguageService.currentLocale, comment: "Deletion impact: utility charges")) }
        if inv > 0 { items.append(String(localized: "\(inv) objetos del inventario", locale: LanguageService.currentLocale, comment: "Deletion impact: inventory items")) }
        return DeletionImpact(items: items)
    }

    /// Lo que desaparece al borrar una propiedad entera. Aquí sí cascadea todo.
    static func forProperty(_ propertyId: UUID) async -> DeletionImpact {
        async let rooms = count(SupabaseTable.rooms, column: "property_id", equals: propertyId)
        async let tenants = count(SupabaseTable.tenants, column: "property_id", equals: propertyId)
        async let income = count(SupabaseTable.income, column: "property_id", equals: propertyId)
        async let expenses = count(SupabaseTable.expenses, column: "property_id", equals: propertyId)
        async let documents = count(SupabaseTable.documents, column: "property_id", equals: propertyId)

        var items: [String] = []
        let (r, t, i, e, d) = await (rooms, tenants, income, expenses, documents)
        if r > 0 { items.append(String(localized: "\(r) habitaciones", locale: LanguageService.currentLocale, comment: "Deletion impact: rooms")) }
        if t > 0 { items.append(String(localized: "\(t) inquilinos", locale: LanguageService.currentLocale, comment: "Deletion impact: tenants")) }
        if i > 0 { items.append(String(localized: "\(i) ingresos", locale: LanguageService.currentLocale, comment: "Deletion impact: income")) }
        if e > 0 { items.append(String(localized: "\(e) gastos", locale: LanguageService.currentLocale, comment: "Deletion impact: expenses")) }
        if d > 0 { items.append(String(localized: "\(d) documentos", locale: LanguageService.currentLocale, comment: "Deletion impact: documents")) }
        return DeletionImpact(items: items)
    }
}
