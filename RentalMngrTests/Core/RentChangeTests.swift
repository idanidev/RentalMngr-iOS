import Foundation
import Testing

@testable import RentalMngr

/// Historial de subidas de renta (#24): cómo se lee de la base, cómo se calcula
/// la variación y qué impide guardar una subida.
struct RentChangeTests {

    private func cambio(de anterior: Decimal?, a nueva: Decimal) -> RentChange {
        RentChange(
            id: UUID(), tenantId: UUID(), propertyId: UUID(),
            previousAmount: anterior, newAmount: nueva, effectiveDate: Date())
    }

    // MARK: - Variación

    @Test("De 400 a 420 es un 5 % más")
    func percentUp() throws {
        let pct = try #require(cambio(de: 400, a: 420).percentChange)
        #expect(abs(pct - 5) < 0.0001)
    }

    @Test("Una bajada sale en negativo")
    func percentDown() throws {
        let pct = try #require(cambio(de: 500, a: 450).percentChange)
        #expect(abs(pct - (-10)) < 0.0001)
    }

    @Test("Sin renta anterior no hay porcentaje que inventar")
    func noPreviousNoPercent() {
        #expect(cambio(de: nil, a: 400).percentChange == nil)
        #expect(cambio(de: 0, a: 400).percentChange == nil)
    }

    // MARK: - Lectura

    @Test("Lee la fila tal como la devuelve la base, con la fecha sin hora")
    func decodesDatabaseRow() throws {
        // `effective_date` es de tipo date: llega como "2026-11-01". Si se
        // interpretara en UTC, en España saldría el 31 de octubre.
        let json = """
            {
              "id": "\(UUID())", "tenant_id": "\(UUID())", "property_id": "\(UUID())",
              "room_id": null, "previous_amount": 400, "new_amount": 420,
              "effective_date": "2026-11-01", "note": "IPC",
              "created_at": "2026-10-06T10:00:00.123456+00:00"
            }
            """.data(using: .utf8)!

        let fila = try JSONDecoder().decode(RentChange.self, from: json)
        let dia = Calendar.current.dateComponents([.year, .month, .day], from: fila.effectiveDate)
        #expect(dia.year == 2026 && dia.month == 11 && dia.day == 1)
        #expect(fila.newAmount == 420)
        #expect(fila.previousAmount == 400)
        #expect(fila.note == "IPC")
    }

    @Test("Al mandar la fecha a la base no se corre de día")
    func encodesDayWithoutShifting() throws {
        let unoDeNoviembre = try #require(
            Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        #expect(RentChange.dayFormatter.string(from: unoDeNoviembre) == "2026-11-01")
    }

    // MARK: - Formulario

    @Test("Un importe válido y distinto se puede guardar")
    func validDraft() {
        let draft = RentChangeDraft(amountText: "420")
        #expect(draft.problem(currentRent: 400) == nil)
    }

    @Test("Acepta coma decimal, como lo escribe un iPhone en español")
    func commaDecimal() {
        let draft = RentChangeDraft(amountText: "412,50")
        #expect(draft.amount == Decimal(string: "412.50"))
        #expect(draft.problem(currentRent: 400) == nil)
    }

    @Test("La misma renta no es una subida")
    func sameAmount() {
        #expect(RentChangeDraft(amountText: "400").problem(currentRent: 400) == .sameAsCurrent)
    }

    @Test("Texto que no es un número, o cero, no se guarda")
    func invalidAmounts() {
        #expect(RentChangeDraft(amountText: "").problem(currentRent: 400) == .notANumber)
        #expect(RentChangeDraft(amountText: "cuatrocientos").problem(currentRent: 400) == .notANumber)
        #expect(RentChangeDraft(amountText: "0").problem(currentRent: 400) == .notPositive)
    }

    @Test("Sin renta actual cualquier importe positivo vale")
    func noCurrentRent() {
        #expect(RentChangeDraft(amountText: "400").problem(currentRent: nil) == nil)
    }
}
