import Foundation
import Supabase

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
        // Surface real backend errors from Supabase — the message (e.g. an RLS/constraint
        // violation) is actionable for the user and not a sensitive internal leak.
        if let pg = self as? PostgrestError {
            return pg.message
        }
        if let auth = self as? AuthError {
            return auth.localizedDescription
        }
        // Foundation/StoreKit/URLError and friends already carry a localized,
        // user-safe description (e.g. "The Internet connection appears to be
        // offline"). Show it rather than a vague generic message — a blank
        // "error inesperado" tells the user nothing and hides the real cause.
        let described = localizedDescription
        if described.isEmpty {
            return String(localized: "Ha ocurrido un error inesperado. Inténtalo de nuevo.", locale: LanguageService.currentLocale)
        }
        return described
    }
}
