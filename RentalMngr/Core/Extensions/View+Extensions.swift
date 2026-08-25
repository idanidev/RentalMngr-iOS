import SwiftUI

extension View {
    /// Alerta de error con opción de reportar.
    ///
    /// El botón importa: antes un fallo dejaba al usuario mirando un texto
    /// técnico sin nada que hacer. Ahora abre un correo ya redactado con el
    /// detalle, la versión y el dispositivo, que es lo que permite arreglarlo.
    func errorAlert(_ error: Binding<String?>, context: String = "") -> some View {
        modifier(ErrorAlertModifier(errorText: error, context: context))
    }

    func loadingOverlay(_ isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

/// Implementación de `errorAlert`. Vive aparte porque necesita estado propio
/// para saber si el sistema puede abrir el correo.
private struct ErrorAlertModifier: ViewModifier {
    @Binding var errorText: String?
    let context: String
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "Algo no ha ido bien", locale: LanguageService.currentLocale, comment: "Error alert title"),
            isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } })
        ) {
            Button(String(localized: "Reportar", locale: LanguageService.currentLocale, comment: "Report error button")) {
                let report = UserFacingError(message: errorText ?? "", context: context)
                if let url = report.reportURL { openURL(url) }
                errorText = nil
            }
            Button(String(localized: "Cerrar", locale: LanguageService.currentLocale, comment: "Dismiss error"), role: .cancel) {}
        } message: {
            if let errorText { Text(errorText) }
        }
    }
}
