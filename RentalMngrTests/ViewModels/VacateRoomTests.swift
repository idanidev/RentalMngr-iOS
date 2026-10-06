import Foundation
import Testing

@testable import RentalMngr

/// Qué hace "marcar como libre".
///
/// Con un inquilino asignado, cambiar solo la marca no servía: la lista deduce
/// la ocupación del inquilino y la volvía a pintar ocupada. En producción había
/// justo una habitación así, marcada libre con el inquilino aún enganchado.
@MainActor
struct VacateRoomTests {

    private func habitacion(ocupada: Bool, conInquilino: Bool) -> Room {
        var room = makeRoom(type: .privateRoom, occupied: ocupada)
        room.tenantId = conInquilino ? UUID() : nil
        return room
    }

    @Test("Ocupada y con inquilino: dejarla libre es darle salida")
    func occupiedWithTenantChecksOut() {
        #expect(RoomListViewModel.vacateAction(for: habitacion(ocupada: true, conInquilino: true)) == .checkOut)
    }

    @Test("Ocupada sin inquilino: basta con cambiar la marca")
    func occupiedWithoutTenantToggles() {
        // Una habitación marcada a mano como ocupada, sin nadie asignado.
        #expect(RoomListViewModel.vacateAction(for: habitacion(ocupada: true, conInquilino: false)) == .toggle)
    }

    @Test("Libre: el botón es 'marcar como ocupada' y solo cambia la marca")
    func vacantToggles() {
        #expect(RoomListViewModel.vacateAction(for: habitacion(ocupada: false, conInquilino: false)) == .toggle)
    }
}
