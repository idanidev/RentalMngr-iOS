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
