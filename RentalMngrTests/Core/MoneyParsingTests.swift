import Foundation
import Testing

@testable import RentalMngr

/// El parseo de importes es lo único que separa "600,50 €" de "0 €" en la base
/// de datos. Estos casos son los que se vieron en producción: teclado español
/// con coma, miles con punto, y entradas ambiguas que antes se truncaban en
/// silencio en vez de rechazarse.
struct MoneyParsingTests {

    @Test("La coma decimal del teclado español no pierde los céntimos")
    func commaDecimal() {
        #expect(Decimal.fromUserInput("600,50") == Decimal(string: "600.5"))
        #expect(Decimal.fromUserInput("89,90") == Decimal(string: "89.9"))
        #expect(Decimal.fromUserInput("0,99") == Decimal(string: "0.99"))
    }

    @Test("El punto decimal sigue funcionando")
    func periodDecimal() {
        #expect(Decimal.fromUserInput("600.50") == Decimal(string: "600.5"))
        #expect(Decimal.fromUserInput("1234") == Decimal(1234))
    }

    @Test("Miles con punto y decimales con coma: 1.500,00 son mil quinientos, no 1,5")
    func groupedThousands() {
        #expect(Decimal.fromUserInput("1.500,00") == Decimal(1500))
        #expect(Decimal.fromUserInput("1.234,50") == Decimal(string: "1234.5"))
    }

    @Test("Con varios separadores manda el último: 1.234.50 son mil doscientos treinta y cuatro con cincuenta")
    func multipleSeparators() {
        // Decimal(string:) devolvía 1.234 aquí, guardando 1,23 € en lugar de 1234,50.
        #expect(Decimal.fromUserInput("1.234.50") == Decimal(string: "1234.5"))
        #expect(Decimal.fromUserInput("1,234.50") == Decimal(string: "1234.5"))
        #expect(Decimal.fromUserInput("1.234.567") == Decimal(1234567))
    }

    @Test("Un grupo final de 3 dígitos es de millares, no decimales")
    func thousandsGrouping() {
        #expect(Decimal.fromUserInput("1.500") == Decimal(1500))
        #expect(Decimal.fromUserInput("1,500") == Decimal(1500))
    }

    @Test("Vacío y basura devuelven nil, nunca cero")
    func emptyAndGarbage() {
        #expect(Decimal.fromUserInput("") == nil)
        #expect(Decimal.fromUserInput("   ") == nil)
        #expect(Decimal.fromUserInput("abc") == nil)
    }

    @Test("Espacios alrededor no molestan")
    func trimsWhitespace() {
        #expect(Decimal.fromUserInput("  350,25  ") == Decimal(string: "350.25"))
    }
}
