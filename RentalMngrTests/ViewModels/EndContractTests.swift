import Foundation
import Testing

@testable import RentalMngr

/// Dar de baja un contrato.
///
/// Antes solo se marcaba al inquilino como inactivo, y su habitación se quedaba
/// con él enganchado: ocupada por alguien que ya no estaba. Dar de baja tiene que
/// hacer las dos cosas, y en un orden que se pueda repetir sin daño si algo falla.
@MainActor
struct EndContractTests {

    @Test("Con habitación: primero la libera y luego desactiva al inquilino")
    func freesRoomThenDeactivates() async throws {
        let servicio = MockTenantService()
        try await servicio.endContract(tenantId: UUID(), roomId: UUID())
        #expect(servicio.callLog == ["unassign", "deactivate"])
    }

    @Test("Sin habitación: solo desactiva")
    func withoutRoomOnlyDeactivates() async throws {
        let servicio = MockTenantService()
        try await servicio.endContract(tenantId: UUID(), roomId: nil)
        #expect(servicio.callLog == ["deactivate"])
    }

    @Test("Si no se puede liberar la habitación, no se desactiva a medias")
    func stopsIfFreeingFails() async {
        // Si fallara al revés —inquilino inactivo y habitación aún ocupada— se
        // volvería al estado que motivó la tarea. Así, el fallo deja todo como
        // estaba y se puede reintentar.
        let servicio = MockTenantService()
        servicio.stubbedError = URLError(.notConnectedToInternet)
        await #expect(throws: URLError.self) {
            try await servicio.endContract(tenantId: UUID(), roomId: UUID())
        }
        #expect(servicio.deactivateCallCount == 0)
    }
}
