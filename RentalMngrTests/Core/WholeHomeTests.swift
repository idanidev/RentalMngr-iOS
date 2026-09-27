import Foundation
import Testing

@testable import RentalMngr

/// Qué registro hace de "la casa" en una vivienda que se alquila entera.
///
/// El inquilino y la renta cuelgan siempre de una habitación, así que una casa
/// entera tiene una por debajo. Si esta lógica elige mal, la tarjeta de la casa
/// enseña una renta o un inquilino que no son; y si crea de más, aparecen dos
/// "casas" dentro de la misma casa.
struct WholeHomeTests {

    @Test("Sin habitaciones no hay unidad")
    func noRooms() {
        #expect(WholeHome.unit(in: []) == nil)
    }

    @Test("La unidad es la privada, nunca una zona común")
    func ignoresCommonAreas() throws {
        let salon = makeRoom(type: .common)
        let casa = makeRoom(type: .privateRoom)
        let unidad = try #require(WholeHome.unit(in: [salon, casa]))
        #expect(unidad.id == casa.id)
    }

    @Test("Solo zonas comunes: no hay dónde poner inquilino")
    func onlyCommonAreas() {
        #expect(WholeHome.unit(in: [makeRoom(type: .common)]) == nil)
    }

    @Test("Si un piso pasa a casa entera, manda la que ya estaba alquilada")
    func prefersTheRentedOne() throws {
        // El caso delicado: al convertir un piso compartido, la tarjeta tiene que
        // enseñar la renta y el inquilino reales, no los de una habitación vacía.
        let vacia = makeRoom(type: .privateRoom, occupied: false, rent: 300)
        let alquilada = makeRoom(type: .privateRoom, occupied: true, rent: 450)
        let unidad = try #require(WholeHome.unit(in: [vacia, alquilada]))
        #expect(unidad.id == alquilada.id)
    }

    @Test("Lo que sobra se enseña aparte, sin la unidad")
    func othersExcludeTheUnit() throws {
        let casa = makeRoom(type: .privateRoom, occupied: true)
        let cocina = makeRoom(type: .common)
        let otra = makeRoom(type: .privateRoom)
        let unidad = try #require(WholeHome.unit(in: [cocina, casa, otra]))

        let otras = WholeHome.others(in: [cocina, casa, otra], besides: unidad)
        #expect(otras.count == 2)
        #expect(!otras.contains { $0.id == unidad.id })
    }

    @Test("Casa entera y vacía: hay que crearle la unidad")
    func createsUnitWhenEmpty() {
        #expect(WholeHome.needsUnit(isSingleUnit: true, existingRooms: 0))
    }

    @Test("Casa entera que ya tenía habitaciones: no se crea otra")
    func doesNotDuplicateUnit() {
        // Crear otra dejaría dos candidatas a "la casa" y ninguna forma clara de
        // elegir entre ellas.
        #expect(!WholeHome.needsUnit(isSingleUnit: true, existingRooms: 3))
    }

    @Test("Un piso por habitaciones nunca recibe una unidad automática")
    func sharedFlatNeverGetsOne() {
        #expect(!WholeHome.needsUnit(isSingleUnit: false, existingRooms: 0))
    }
}
