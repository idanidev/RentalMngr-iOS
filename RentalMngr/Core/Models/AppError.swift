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
    /// Traducción de los límites que aplica el servidor.
    fileprivate static func planLimitMessage(for raw: String) -> String? {
        if raw.contains("free_tier_unit_limit_reached") {
            return String(localized: "Has alcanzado las 3 unidades del plan gratuito. Hazte Premium para añadir las que necesites.", locale: LanguageService.currentLocale, comment: "Free tier unit limit")
        }
        if raw.contains("photo_daily_limit_reached") {
            return String(localized: "Has subido muchas fotos hoy. Inténtalo de nuevo mañana.", locale: LanguageService.currentLocale, comment: "Daily photo limit")
        }
        if raw.contains("photo_quota_reached") {
            return String(localized: "Has alcanzado el límite de fotos de tu plan. Hazte Premium para subir más.", locale: LanguageService.currentLocale, comment: "Photo quota")
        }
        if raw.contains("document_quota_reached") {
            return String(localized: "Has alcanzado el límite de documentos de tu plan. Hazte Premium para guardar más.", locale: LanguageService.currentLocale, comment: "Document quota")
        }
        if raw.contains("transaction_already_used") {
            return String(localized: "Esa compra ya está activada en otra cuenta.", locale: LanguageService.currentLocale, comment: "Purchase already used")
        }
        return nil
    }

    /// True si el error viene de un límite del plan: la interfaz puede ofrecer Premium.
    var isPlanLimit: Bool {
        guard let pg = self as? PostgrestError else { return false }
        return Self.planLimitMessage(for: pg.message) != nil
    }

    var safeUserMessage: String {
        if let appError = self as? AppError {
            return appError.errorDescription ?? String(localized: "Ha ocurrido un error", locale: LanguageService.currentLocale)
        }
        // Surface real backend errors from Supabase — the message (e.g. an RLS/constraint
        // violation) is actionable for the user and not a sensitive internal leak.
        if let pg = self as? PostgrestError {
            // Los límites de plan los aplica la base de datos y llegan como
            // códigos internos. Se traducen aquí para que el usuario lea algo
            // accionable en vez de "free_tier_unit_limit_reached".
            if let planMessage = Self.planLimitMessage(for: pg.message) {
                return planMessage
            }
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
