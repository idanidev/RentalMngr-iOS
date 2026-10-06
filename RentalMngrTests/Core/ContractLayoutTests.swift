import Foundation
import PDFKit
import Testing
import UIKit

@testable import RentalMngr

/// Cómo queda el contrato en papel: el tamaño de los huecos y que la firma no se
/// parta entre dos hojas.
///
/// Son cosas que no se ven en la app, solo al imprimir, y por eso se colaron:
/// huecos de 14 guiones donde no cabía un nombre con dos apellidos, y un bloque
/// de firma con los títulos en una hoja y los nombres en la siguiente.
@MainActor
struct ContractLayoutTests {

    /// Media columna del bloque de firma: A4 (595,2) menos márgenes (40 + 40)
    /// menos el hueco entre columnas (24), entre dos.
    private let mediaColumna: CGFloat = (595.2 - 80 - 24) / 2

    private func ancho(_ texto: String) -> CGFloat {
        (texto as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 11)]).width
    }

    // MARK: - Huecos

    @Test("El hueco del nombre da para un nombre con dos apellidos")
    func nameBlankIsLongEnough() {
        // Escrito a mano, "María del Carmen Fernández Gutiérrez" pide unos 180 pt.
        #expect(ancho(PDFGenerator.blank(for: "{{tenant_name}}")) >= 180)
        #expect(ancho(PDFGenerator.blank(for: "{{landlord_name}}")) >= 180)
    }

    @Test("Con \"Fdo.:\" delante, el nombre cabe en media columna sin saltar de línea")
    func nameBlankFitsInSignatureColumn() {
        // Si no cupiera, la línea de firma se partiría en dos dentro de su columna.
        let linea = "Fdo.: " + PDFGenerator.blank(for: "{{tenant_name}}")
        #expect(ancho(linea) < mediaColumna)
    }

    @Test("Cada dato tiene el hueco que pide: el nombre, más que el DNI o un importe")
    func blanksAreSizedPerField() {
        let nombre = PDFGenerator.blank(for: "{{tenant_name}}").count
        let dni = PDFGenerator.blank(for: "{{tenant_dni}}").count
        let renta = PDFGenerator.blank(for: "{{rent}}").count
        #expect(nombre > dni)
        #expect(dni > renta)
        // El formato antiguo, con llaves simples, sigue el mismo criterio.
        #expect(PDFGenerator.blank(for: "{tenantName}").count == nombre)
    }

    // MARK: - Firma

    /// La firma como suelen escribirla: títulos en mayúsculas separados por un
    /// tabulador, huecos para firmar y los nombres debajo.
    private let firma = """
        **EL ARRENDADOR**\t**EL ARRENDATARIO**




        Fdo.: {{landlord_name}}\tFdo.: {{tenant_name}}
        DNI: {{landlord_dni}}\tDNI: {{tenant_dni}}
        """

    private func contrato(conRelleno lineas: Int) -> String {
        let relleno = (0..<lineas).map {
            "Cláusula de relleno número \($0), que empuja la firma hacia abajo para probar el final de la página."
        }
        return (["Contrato de arrendamiento"] + relleno + ["", firma]).joined(separator: "\n")
    }

    private func pagina(de texto: String, en doc: PDFDocument) -> Int? {
        (0..<doc.pageCount).first { doc.page(at: $0)?.string?.contains(texto) == true }
    }

    @Test("La firma nunca se parte entre dos hojas, caiga donde caiga")
    func signatureNeverSplits() async throws {
        // Se prueban todas las posiciones: con 0 líneas delante la firma queda
        // arriba, y hacia las 45 ya ha pasado a la segunda hoja. Por medio pasa
        // justo por el borde, que es donde se partía.
        for lineas in 0..<50 {
            let data = try await PDFGenerator().generateContract(
                property: makeProperty(), template: contrato(conRelleno: lineas),
                blankTemplate: true)
            let doc = try #require(PDFDocument(data: data))

            let titulos = try #require(
                pagina(de: "EL ARRENDATARIO", en: doc), "sin títulos de firma con \(lineas) líneas")
            let nombres = try #require(
                pagina(de: "Fdo.:", en: doc), "sin nombres de firma con \(lineas) líneas")
            #expect(titulos == nombres,
                "con \(lineas) líneas de relleno la firma se parte: títulos en la hoja \(titulos + 1), nombres en la \(nombres + 1)")
        }
    }

    @Test("Una fila de firma en mayúsculas no se toma por un título")
    func uppercaseSignatureRowIsNotAHeading() async throws {
        // Era la causa de fondo: "**EL ARRENDADOR**<tab>**EL ARRENDATARIO**" es
        // corta y en mayúsculas, se pintaba como título y nunca llegaba al código
        // de la firma. Pintada a dos columnas, los dos títulos quedan separados.
        let data = try await PDFGenerator().generateContract(
            property: makeProperty(), template: firma, blankTemplate: true)
        let texto = try #require(PDFDocument(data: data)?.string)

        #expect(!texto.contains("EL ARRENDADOR\tEL ARRENDATARIO"))
        #expect(texto.contains("EL ARRENDADOR"))
        #expect(texto.contains("EL ARRENDATARIO"))
    }
}
