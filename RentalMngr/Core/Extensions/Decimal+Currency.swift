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
    /// A plain `Decimal(string:)` assumes a period decimal separator, so on a
    /// Spanish-locale `.decimalPad` (which emits a comma) "1.500,00" silently
    /// truncates to 1.5 — corrupting stored money. This parses with the device
    /// locale first, then falls back to comma/period normalization. Returns nil
    /// for empty or invalid input.
    static func fromUserInput(_ text: String) -> Decimal? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return nil }

        // 1) Device-locale aware parse (respects the user's own separators).
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: clean) {
            return number.decimalValue
        }
        // 2) Comma-as-decimal → period ("1234,50"). Guard against ambiguous
        // multi-separator input like "1.234.50": Decimal(string:) parses only the
        // longest valid prefix ("1.234"), silently corrupting the value — so
        // reject anything left with more than one "." rather than truncating it.
        let dotNormalized = clean.replacingOccurrences(of: ",", with: ".")
        if dotNormalized.filter({ $0 == "." }).count <= 1,
            let dec = Decimal(string: dotNormalized) {
            return dec
        }
        // 3) es_ES fallback for grouped input on a non-es device ("1.234,50" →
        // 1234.5). NumberFormatter strips grouping separators; a bare
        // Decimal(string:) would not.
        let esFormatter = NumberFormatter()
        esFormatter.numberStyle = .decimal
        esFormatter.locale = Locale(identifier: "es_ES")
        if let number = esFormatter.number(from: clean) {
            return number.decimalValue
        }
        return nil
    }
}
