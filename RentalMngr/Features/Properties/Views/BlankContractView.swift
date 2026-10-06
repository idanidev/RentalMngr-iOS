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
    /// Tus datos de arrendador son lo único que no cambia de un contrato a otro,
    /// así que por defecto salen puestos. Se pueden quitar para un modelo neutro.
    @State private var includeLandlord = true
    @State private var landlord: LandlordProfile?

    private var landlordIsEmpty: Bool {
        (landlord?.fullName ?? "").isEmpty && (landlord?.dni ?? "").isEmpty
    }

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
                        .id(pdfURL)

                    VStack(spacing: 10) {
                        Toggle(isOn: $includeLandlord) {
                            Text(String(localized: "Poner mis datos de arrendador",
                                locale: LanguageService.currentLocale,
                                comment: "Toggle: keep the landlord's name and ID in the blank contract"))
                                .font(.subheadline)
                        }

                        if includeLandlord && landlordIsEmpty {
                            // Sin esto el interruptor parece no hacer nada.
                            Text(String(localized: "Tu perfil de arrendador está vacío. Rellénalo en Ajustes para que salgan tu nombre y tu DNI.",
                                locale: LanguageService.currentLocale,
                                comment: "Hint when the landlord profile has no data"))
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text(includeLandlord
                            ? String(localized: "Tus datos y la dirección de la vivienda salen puestos; lo del inquilino, las fechas y los importes quedan en blanco. Las cláusulas son las de la plantilla de esta propiedad.",
                                locale: LanguageService.currentLocale,
                                comment: "Explanation under the blank contract, landlord data included")
                            : String(localized: "La dirección de la vivienda sale puesta; el resto queda en blanco para escribirlo a mano. Las cláusulas son las de la plantilla de esta propiedad.",
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
        .task(id: includeLandlord) { await generate() }
        .onDisappear {
            if let pdfURL { try? FileManager.default.removeItem(at: pdfURL) }
        }
    }

    private func generate() async {
        // Las variables propias se traen igual que en el contrato normal: en
        // blanco también tienen que salir como huecos, no desaparecer.
        let customVars = (try? await ContractVariableService().fetchVariables()) ?? []
        if landlord == nil {
            landlord = try? await appState.userProfileService.getLandlordProfile()
        }
        do {
            let data = try await PDFGenerator().generateContract(
                property: property,
                landlord: landlord,
                customVariables: customVars,
                blankTemplate: true,
                includeLandlord: includeLandlord
            )
            // Una subcarpeta por variante: el visor recarga cuando cambia la URL,
            // y así el fichero que se comparte conserva un nombre limpio.
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent(includeLandlord ? "contrato-con-datos" : "contrato-en-blanco")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(fileName)
            try data.write(to: url)
            if let previous = pdfURL, previous != url {
                try? FileManager.default.removeItem(at: previous)
            }
            pdfURL = url
        } catch where error.isCancellation {
            // Salir de la pantalla o cambiar el interruptor cancela la tarea.
        } catch {
            errorMessage = error.safeUserMessage
        }
        isLoading = false
    }
}
