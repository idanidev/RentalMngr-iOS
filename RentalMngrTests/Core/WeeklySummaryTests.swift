import Foundation
import Testing

@testable import RentalMngr

/// El texto del resumen semanal.
///
/// Hasta ahora el aviso llevaba la descripción del ajuste —"Occupancy, income and
/// outstanding payments — every Monday at 9:00 AM"—: ni una cifra, y decía lunes
/// aunque se hubiera elegido otro día.
@MainActor
struct WeeklySummaryTests {

    private func resumen(_ ocupadas: Int, de total: Int, fianzas: Int = 0) -> String {
        LocalNotificationScheduler.weeklySummaryBody(
            occupied: ocupadas, total: total, depositsPending: fianzas)
    }

    @Test("Lleva las cifras de ocupación")
    func showsOccupancy() {
        #expect(resumen(7, de: 9).contains("7 de 9"))
    }

    @Test("Dice cuántas libres, en singular y en plural")
    func vacantCount() {
        #expect(resumen(8, de: 9).contains("1 libre."))
        #expect(resumen(6, de: 9).contains("3 libres."))
    }

    @Test("Con todo alquilado lo dice, no '0 libres'")
    func fullyRented() {
        let texto = resumen(9, de: 9)
        #expect(texto.contains("Todo ocupado"))
        #expect(!texto.contains("0 libre"))
    }

    @Test("Las fianzas pendientes solo aparecen si las hay")
    func depositsOnlyWhenPending() {
        #expect(!resumen(9, de: 9).contains("fianza"))
        #expect(resumen(9, de: 9, fianzas: 1).contains("1 fianza pendiente."))
        #expect(resumen(9, de: 9, fianzas: 2).contains("2 fianzas pendientes."))
    }

    @Test("Sin habitaciones no da cifras vacías")
    func noRooms() {
        let texto = resumen(0, de: 0)
        #expect(!texto.contains("0 de 0"))
        #expect(!texto.isEmpty)
    }

    @Test("Ya no menciona un día concreto")
    func noHardcodedWeekday() {
        // El día es configurable; el texto no puede prometer "lunes".
        let texto = resumen(5, de: 9, fianzas: 1).lowercased()
        #expect(!texto.contains("monday"))
        #expect(!texto.contains("lunes"))
    }
}
