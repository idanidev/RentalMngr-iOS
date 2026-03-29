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
}
