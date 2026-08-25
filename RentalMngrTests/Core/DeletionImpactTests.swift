import Foundation
import Testing

@testable import RentalMngr

/// El texto que avisa de lo que se borra en cascada.
///
/// Se lee en el momento en que alguien decide si se carga dos años de datos,
/// así que una frase mal montada ("24 ingresos y" o ", y 8 objetos") importa
/// más de lo que parece.
struct DeletionImpactTests {

    @Test("Sin nada que arrastrar, no hay frase que enseñar")
    func empty() {
        let impact = DeletionImpact(items: [])
        #expect(impact.isEmpty)
        #expect(impact.sentence.isEmpty)
    }

    @Test("Un solo elemento va tal cual, sin conjunción")
    func single() {
        let impact = DeletionImpact(items: ["24 ingresos registrados"])
        #expect(!impact.isEmpty)
        #expect(impact.sentence == "24 ingresos registrados")
    }

    @Test("Dos elementos se unen con 'y', sin coma")
    func two() {
        let impact = DeletionImpact(items: ["24 ingresos", "8 objetos del inventario"])
        #expect(impact.sentence == "24 ingresos y 8 objetos del inventario")
    }

    @Test("Tres o más: comas y la 'y' solo antes del último")
    func many() {
        let impact = DeletionImpact(items: ["24 ingresos", "5 cargos", "8 objetos"])
        #expect(impact.sentence == "24 ingresos, 5 cargos y 8 objetos")
        // Lo que no debe pasar: quedar colgando o duplicar la conjunción.
        #expect(!impact.sentence.hasSuffix(" y"))
        #expect(!impact.sentence.contains(", y "))
    }
}
