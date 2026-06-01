import Foundation

/// Unified error type for the app — standardizes error handling across services
enum AppError: LocalizedError {
    case network(String)
    case decoding(String)
    case authenticationRequired
    case notFound(String)
    case validation(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .network(let msg): return String(localized: "Network error: \(msg)", locale: LanguageService.currentLocale, comment: "AppError")
        case .decoding(let msg): return String(localized: "Data error: \(msg)", locale: LanguageService.currentLocale, comment: "AppError")
        case .authenticationRequired: return String(localized: "Session expired. Please sign in again.", locale: LanguageService.currentLocale, comment: "AppError")
        case .notFound(let resource): return String(localized: "\(resource) not found", locale: LanguageService.currentLocale, comment: "AppError")
        case .validation(let msg): return msg
        case .unknown(let error): return error.localizedDescription
        }
    }

}

// MARK: - Cancellation detection (URLError.cancelled, CancellationError, etc.)

extension Error {
    /// Whether this error represents a task/request cancellation — should be silently ignored.
    var isCancellation: Bool {
        self is CancellationError
            || (self as? URLError)?.code == .cancelled
            || localizedDescription.contains("cancelled")
            || localizedDescription.contains("cancelada")
    }
}

// MARK: - Safe error messages for UI (never leak internals)

extension Error {
    var safeUserMessage: String {
        if let appError = self as? AppError {
            return appError.errorDescription ?? String(localized: "Ha ocurrido un error", locale: LanguageService.currentLocale)
        }
        // Never expose raw system errors to the user
        return String(localized: "Ha ocurrido un error inesperado. Inténtalo de nuevo.", locale: LanguageService.currentLocale)
    }
}
