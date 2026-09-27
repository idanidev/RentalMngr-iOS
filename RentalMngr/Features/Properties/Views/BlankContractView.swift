import PDFKit
import SwiftUI

/// El contrato de la propiedad con todos los huecos sin rellenar, para imprimir
/// y completar a mano.
///
/// Sirve para cuando todavía no hay inquilino: una visita, un contrato de papel,
/// o tener el modelo a mano. Usa la plantilla real de la propiedad, así que las
/// cláusulas son las tuyas; lo único que cambia es que no se sustituye ningún
/// dato.
struct BlankContractView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let property: Property

    @State private var pdfURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var fileName: String {
        let safeName = property.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        return "Contrato_en_blanco_\(safeName).pdf"
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingView(
                    message: String(localized: "Generando contrato en blanco…",
                        locale: LanguageService.currentLocale,
                        comment: "Loading message while generating the blank contract"))
            } else if let pdfURL {
                VStack(spacing: 0) {
                    PDFKitView(url: pdfURL)

                    VStack(spacing: 10) {
                        Text(String(localized: "Todos los datos quedan en blanco para escribirlos a mano. Las cláusulas son las de la plantilla de esta propiedad.",
                            locale: LanguageService.currentLocale,
                            comment: "Explanation shown under the blank contract"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        ShareLink(
                            item: pdfURL,
                            preview: SharePreview(
                                String(localized: "Contrato en blanco",
                                    locale: LanguageService.currentLocale,
                                    comment: "Share preview title for the blank contract"),
                                image: Image(systemName: "doc.text"))
                        ) {
                            Label(
                                String(localized: "Compartir o imprimir",
                                    locale: LanguageService.currentLocale,
                                    comment: "Button to share or print the blank contract"),
                                systemImage: "square.and.arrow.up"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            } else {
                EmptyStateView(
                    icon: "doc.text",
                    title: String(localized: "No se ha podido generar",
                        locale: LanguageService.currentLocale,
                        comment: "Blank contract error title"),
                    subtitle: String(localized: "Inténtalo otra vez. Si se repite, repórtalo.",
                        locale: LanguageService.currentLocale,
                        comment: "Blank contract error subtitle")
                )
            }
        }
        .navigationTitle(String(localized: "Contrato en blanco",
            locale: LanguageService.currentLocale, comment: "Blank contract navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // En Mac no hay gesto para cerrar una hoja (MAC_DESIGN): siempre un botón.
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cerrar", locale: LanguageService.currentLocale,
                    comment: "Close button")) {
                    dismiss()
                }
            }
        }
        .errorAlert($errorMessage, context: "Contrato en blanco")
        .task { await generate() }
        .onDisappear {
            if let pdfURL { try? FileManager.default.removeItem(at: pdfURL) }
        }
    }

    private func generate() async {
        // Las variables propias se traen igual que en el contrato normal: en
        // blanco también tienen que salir como huecos, no desaparecer.
        let customVars = (try? await ContractVariableService().fetchVariables()) ?? []
        do {
            let data = try await PDFGenerator().generateContract(
                property: property,
                customVariables: customVars,
                blankTemplate: true
            )
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: url)
            pdfURL = url
        } catch where error.isCancellation {
            // Salir de la pantalla cancela la tarea; no es un fallo.
        } catch {
            errorMessage = error.safeUserMessage
        }
        isLoading = false
    }
}
