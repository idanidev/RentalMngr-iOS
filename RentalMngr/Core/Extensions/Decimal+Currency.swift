import Foundation

extension Decimal {
    /// Formats as currency with the given ISO 4217 code. Locale-aware.
    /// - Parameters:
    ///   - currencyCode: ISO 4217 currency code (default: current locale's currency or "EUR")
    ///   - showDecimals: Whether to show fractional digits (default: false)
    func formatted(currencyCode: String? = nil, showDecimals: Bool = false) -> String {
        let code = currencyCode ?? Locale.current.currency?.identifier ?? "EUR"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = showDecimals ? 2 : 0
        formatter.locale = Locale.current
        return formatter.string(from: self as NSDecimalNumber) ?? "\(code) 0"
    }

    /// Convenience for EUR formatting (backwards compatible but deprecated)
    @available(*, deprecated, message: "Use formatted() for locale-aware currency")
    func formattedEUR(showDecimals: Bool = false) -> String {
        formatted(currencyCode: "EUR", showDecimals: showDecimals)
    }

    /// Parses a user-typed monetary amount, tolerating both comma and period
    /// decimal separators ("1.234,50", "1234,50", "1234.50", "1,234.50").
    ///
    /// `Decimal(string:)` asume punto decimal, así que en un teclado español
    /// (que escribe coma) "1.500,00" se truncaba a 1,5 y corrompía el importe.
    ///
    /// No usa el locale del dispositivo a propósito: `NumberFormatter` en un
    /// iPhone en inglés lee "600,50" como 60050, un error de 100×. La regla es
    /// determinista — el último separador es el decimal, salvo que separe un
    /// grupo de 3 dígitos, que entonces es de millares. Devuelve nil si está
    /// vacío o no es un número, nunca cero.
    static func fromUserInput(_ text: String) -> Decimal? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !clean.isEmpty else { return nil }
        guard clean.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }) else { return nil }

        // Regla determinista, sin depender del locale del dispositivo:
        // el ÚLTIMO separador es el decimal salvo que separe un grupo de 3
        // dígitos (entonces es de millares). Así "600,50" son 600,5 tanto en un
        // iPhone español como en uno inglés — fiarse del locale convertía
        // "600,50" en 60050 en un dispositivo en inglés.
        let separators = clean.filter { $0 == "." || $0 == "," }
        guard !separators.isEmpty else { return Decimal(string: clean) }

        guard let lastIndex = clean.lastIndex(where: { $0 == "." || $0 == "," }) else {
            return Decimal(string: clean)
        }
        let tail = String(clean[clean.index(after: lastIndex)...])
        let head = String(clean[clean.startIndex..<lastIndex])

        // Grupo final de 3 dígitos con algo delante = millares ("1.500" son mil quinientos).
        let lastIsGrouping = tail.count == 3 && tail.allSatisfy(\.isNumber) && !head.isEmpty

        if lastIsGrouping {
            let digitsOnly = clean.filter { $0.isNumber || $0 == "-" }
            return Decimal(string: digitsOnly)
        }

        guard !tail.isEmpty, tail.allSatisfy(\.isNumber) else { return nil }
        let integerPart = head.filter { $0.isNumber || $0 == "-" }
        guard !integerPart.isEmpty else { return Decimal(string: "0.\(tail)") }
        return Decimal(string: "\(integerPart).\(tail)")
    }
}
