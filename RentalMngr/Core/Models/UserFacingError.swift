import Foundation
import Supabase
import UIKit

/// Un error tal y como debe presentarse a una persona.
///
/// Separa dos cosas que antes iban juntas y en crudo:
/// - `message`: qué le ha pasado, en su idioma y sin jerga.
/// - `technical`: el texto original del servidor, que el usuario no necesita
///   leer pero sí hace falta para arreglarlo.
///
/// Nace de un caso real: la app mostraba
/// *"Could not find the function public.remove_property_access(...) in the
/// schema cache"* a un casero que solo quería quitarle el acceso a alguien.
struct UserFacingError: Identifiable {
    let id = UUID()
    /// Lo que se enseña en la alerta.
    let message: String
    /// Detalle original, solo para el informe.
    let technical: String
    /// Dónde ocurrió, para poder reproducirlo.
    let context: String

    init(_ error: Error, context: String = "") {
        self.technical = Self.rawDetail(of: error)
        self.message = Self.humanMessage(for: error, raw: self.technical)
        self.context = context
    }

    init(message: String, technical: String = "", context: String = "") {
        self.message = message
        self.technical = technical.isEmpty ? message : technical
        self.context = context
    }

    // MARK: - Traducción

    private static func rawDetail(of error: Error) -> String {
        if let pg = error as? PostgrestError {
            return [pg.code, pg.message, pg.hint, pg.detail]
                .compactMap { $0 }.joined(separator: " · ")
        }
        return String(describing: error)
    }

    /// Convierte fallos técnicos en algo accionable. Cuando no reconoce el
    /// error, prefiere una frase honesta ("no hemos podido…") antes que soltar
    /// el texto del servidor: si el usuario no puede hacer nada con él, solo
    /// genera desconfianza. El detalle sigue estando en el informe.
    private static func humanMessage(for error: Error, raw: String) -> String {
        if let planMessage = error.planLimitUserMessage {
            return planMessage
        }

        let lower = raw.lowercased()

        // Función o columna que no existe: es un fallo NUESTRO, no del usuario.
        if lower.contains("could not find the function")
            || lower.contains("schema cache")
            || lower.contains("does not exist")
            || lower.contains("pgrst202") {
            return String(
                localized: "Esta acción no está disponible ahora mismo por un fallo de la app. No es culpa tuya y tus datos están intactos. Repórtalo y lo arreglamos.",
                locale: LanguageService.currentLocale, comment: "Missing backend function")
        }

        // Permisos.
        if lower.contains("permission denied") || lower.contains("row-level security")
            || lower.contains("42501") || lower.contains("violates row-level") {
            return String(
                localized: "No tienes permiso para hacer esto en esta propiedad. Si crees que deberías tenerlo, pide al propietario que revise tu acceso.",
                locale: LanguageService.currentLocale, comment: "Permission denied")
        }

        // Duplicados.
        if lower.contains("duplicate key") || lower.contains("23505") {
            return String(
                localized: "Eso ya existe. Revisa la lista antes de volver a añadirlo.",
                locale: LanguageService.currentLocale, comment: "Duplicate")
        }

        // Red.
        if error.isNetworkFailure {
            return String(
                localized: "Sin conexión. Comprueba tu red e inténtalo de nuevo; no se ha perdido nada.",
                locale: LanguageService.currentLocale, comment: "Network error")
        }

        // Sesión.
        if error is AuthError || lower.contains("jwt") || lower.contains("not_authenticated") {
            return String(
                localized: "Tu sesión ha caducado. Vuelve a iniciar sesión.",
                locale: LanguageService.currentLocale, comment: "Session expired")
        }

        return String(
            localized: "No hemos podido completar la acción. Tus datos están intactos. Si se repite, repórtalo y lo miramos.",
            locale: LanguageService.currentLocale, comment: "Generic error")
    }

    // MARK: - Informe

    /// Correo con todo lo necesario para reproducir el fallo, ya redactado.
    var reportURL: URL? {
        let app = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current
        let body = """
            Cuéntanos qué estabas haciendo:


            ────────────────
            Datos técnicos (no los borres, son los que permiten arreglarlo)

            Dónde: \(context.isEmpty ? "sin especificar" : context)
            Error: \(technical)
            App: \(app) (\(build))
            Sistema: \(device.systemName) \(device.systemVersion)
            Modelo: \(device.model)
            Fecha: \(ISO8601DateFormatter().string(from: Date()))
            """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@rentalmngr.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Error en RentalMngr"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

// MARK: - Ayudas

extension Error {
    /// Mensaje de límite de plan, si lo es.
    var planLimitUserMessage: String? {
        guard let pg = self as? PostgrestError else { return nil }
        let raw = pg.message
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

    var isNetworkFailure: Bool {
        guard let urlError = self as? URLError else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .timedOut,
                .cannotFindHost, .cannotConnectToHost, .dataNotAllowed]
            .contains(urlError.code)
    }
}
