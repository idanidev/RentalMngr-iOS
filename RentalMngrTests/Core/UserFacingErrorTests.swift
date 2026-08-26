import Foundation
import Supabase
import Testing

@testable import RentalMngr

/// Lo que ve el usuario cuando algo falla.
///
/// Estos casos salen de errores que aparecieron de verdad en producción, no de
/// supuestos. El objetivo es que nunca vuelva a leerse jerga: si un texto
/// técnico se cuela en la alerta, uno de estos tests falla.
struct UserFacingErrorTests {

    private func postgrest(_ message: String, code: String? = nil) -> PostgrestError {
        PostgrestError(detail: nil, hint: nil, code: code, message: message)
    }

    @Test("La función que no existe se explica como fallo de la app, no del usuario")
    func missingFunction() {
        // El error real que veía un casero al quitar un acceso.
        let error = postgrest(
            "Could not find the function public.remove_property_access(p_property_id, p_user_id) in the schema cache")
        let shown = UserFacingError(error).message

        #expect(!shown.contains("schema cache"))
        #expect(!shown.contains("public."))
        #expect(shown.lowercased().contains("culpa tuya"))
    }

    @Test("Permiso denegado explica qué hacer, sin hablar de RLS")
    func permissionDenied() {
        let shown = UserFacingError(postgrest("new row violates row-level security policy")).message
        #expect(!shown.lowercased().contains("row-level"))
        #expect(shown.lowercased().contains("permiso"))
    }

    @Test("Clave duplicada se traduce a algo entendible")
    func duplicate() {
        let shown = UserFacingError(postgrest("duplicate key value violates unique constraint", code: "23505")).message
        #expect(!shown.lowercased().contains("duplicate key"))
        #expect(shown.lowercased().contains("ya existe"))
    }

    @Test("Los límites de plan mantienen su mensaje y ofrecen Premium")
    func planLimit() {
        let shown = UserFacingError(postgrest("free_tier_unit_limit_reached")).message
        #expect(!shown.contains("free_tier"))
        #expect(shown.contains("Premium"))
    }

    @Test("Un error desconocido no filtra el texto del servidor")
    func unknownStaysQuiet() {
        let raw = "PGRST999 something exploded in the pipeline at offset 42"
        let error = UserFacingError(postgrest(raw))

        // El usuario no lo lee...
        #expect(!error.message.contains("PGRST999"))
        #expect(!error.message.contains("offset 42"))
        // ...pero sigue disponible para el informe.
        #expect(error.technical.contains("PGRST999"))
    }

    @Test("Sin conexión se distingue de un fallo de la app")
    func networkError() {
        let shown = UserFacingError(URLError(.notConnectedToInternet)).message
        #expect(shown.lowercased().contains("conexión"))
    }

    @Test("El informe lleva el detalle técnico y dónde ocurrió")
    func reportCarriesDiagnostics() throws {
        let error = UserFacingError(
            postgrest("Could not find the function public.foo in the schema cache"),
            context: "Compartir propiedad")
        let url = try #require(error.reportURL)
        let body = url.absoluteString.removingPercentEncoding ?? ""

        #expect(url.scheme == "mailto")
        #expect(body.contains("Compartir propiedad"))
        #expect(body.contains("schema cache"))

        // La dirección tiene que existir. Estuvo apuntando a support@rentalmngr.app,
        // un dominio sin registrar: los informes rebotaban y nadie los leía.
        // Se comprueba sobre la cadena porque `url.path` viene vacío en un
        // mailto:, que es una URL opaca y no jerárquica.
        #expect(url.absoluteString.hasPrefix("mailto:idanideveloper@gmail.com?"))
        #expect(!url.absoluteString.contains("rentalmngr.app"))
    }
}
