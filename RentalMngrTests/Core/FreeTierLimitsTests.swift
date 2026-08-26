import Foundation
import Testing

@testable import RentalMngr

/// El recuento de unidades del plan gratuito.
///
/// Tiene que dar exactamente lo mismo que la función `managed_units` de la base:
///
/// ```sql
/// SELECT (SELECT COUNT(*) FROM properties p
///           WHERE p.owner_id = uid AND p.is_single_unit)
///      + (SELECT COUNT(*) FROM rooms r JOIN properties p ON p.id = r.property_id
///           WHERE p.owner_id = uid AND NOT p.is_single_unit);
/// ```
///
/// Si se separan, el usuario ve anunciado un límite y sufre otro. Ya pasó: el
/// cliente bloqueaba en la primera propiedad mientras el servidor dejaba tres.
struct FreeTierLimitsTests {

    private func property(singleUnit: Bool, rooms: Int) -> Property {
        let id = UUID()
        return makeProperty(
            id: id,
            rooms: (0..<rooms).map { _ in makeRoom(propertyId: id) },
            isSingleUnit: singleUnit)
    }

    @Test("Sin propiedades no hay unidades")
    func empty() {
        #expect(FreeTierLimits.managedUnits(in: []) == 0)
    }

    @Test("Un piso compartido cuenta una unidad por habitación")
    func sharedCountsRooms() {
        #expect(FreeTierLimits.managedUnits(in: [property(singleUnit: false, rooms: 4)]) == 4)
    }

    @Test("Una casa entera cuenta 1 aunque tenga cinco habitaciones")
    func wholeHouseCountsOne() {
        // Es la razón de ser de `is_single_unit`: ahí las habitaciones son
        // organización interna, no cosas que se alquilan por separado.
        #expect(FreeTierLimits.managedUnits(in: [property(singleUnit: true, rooms: 5)]) == 1)
    }

    @Test("Una casa entera sin habitaciones sigue contando 1")
    func wholeHouseWithoutRooms() {
        #expect(FreeTierLimits.managedUnits(in: [property(singleUnit: true, rooms: 0)]) == 1)
    }

    @Test("Un piso compartido sin habitaciones todavía no consume nada")
    func sharedWithoutRooms() {
        #expect(FreeTierLimits.managedUnits(in: [property(singleUnit: false, rooms: 0)]) == 0)
    }

    @Test("Mezcla: dos casas enteras y un piso de 3 son 5 unidades")
    func mixed() {
        let unidades = FreeTierLimits.managedUnits(in: [
            property(singleUnit: true, rooms: 6),
            property(singleUnit: true, rooms: 1),
            property(singleUnit: false, rooms: 3),
        ])
        #expect(unidades == 5)
    }

    @Test("Tres habitaciones agotan justo el plan gratuito")
    func exactlyAtTheLimit() {
        #expect(
            FreeTierLimits.managedUnits(in: [property(singleUnit: false, rooms: 3)])
                == FreeTierLimits.maxUnits)
    }
}
