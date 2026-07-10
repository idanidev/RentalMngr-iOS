import SwiftUI

// MARK: - Tab view: preview only, edit opens a sheet

struct PropertyContractView: View {
    let propertyId: UUID
    @Binding var property: Property
    var canEdit: Bool = true
    @Environment(AppState.self) private var appState

    @State private var templateText: String = ""
    @State private var isLoading = false
    @State private var showEditor = false
    @State private var customVariables: [ContractVariable] = []
    @State private var landlord: LandlordProfile?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if templateText.isEmpty {
                emptyState
            } else {
                previewContent
            }
        }
        .task { await loadTemplate() }
        .task { customVariables = (try? await ContractVariableService().fetchVariables()) ?? [] }
        .task { landlord = try? await appState.userProfileService.getLandlordProfile() }
        .sheet(isPresented: $showEditor) {
            Task { await loadTemplate() }  // refresh after editing
        } content: {
            NavigationStack {
                ContractEditorSheet(
                    propertyId: propertyId,
                    property: $property,
                    initialText: templateText
                )
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showEditor = true
                    } label: {
                        Label(
                            String(
                                localized: "Editar", locale: LanguageService.currentLocale,
                                comment: "Edit contract template button"),
                            systemImage: "pencil"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewContent: some View {
        ScrollView {
            Text(renderedPreview)
                .font(.body)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(
                    localized: "Sin plantilla de contrato", locale: LanguageService.currentLocale,
                    comment: "Empty state title for contract tab"),
                systemImage: "doc.text"
            )
        } description: {
            Text(
                String(
                    localized: "Pulsa Editar para escribir la plantilla de contrato de esta propiedad.",
                    locale: LanguageService.currentLocale,
                    comment: "Empty state description for contract tab"))
        } actions: {
            if canEdit {
                Button {
                    showEditor = true
                } label: {
                    Text(
                        String(
                            localized: "Editar plantilla", locale: LanguageService.currentLocale,
                            comment: "Empty state action button"))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Rendered preview with placeholder values

    /// Real landlord profile when loaded, else a clearly-labelled placeholder
    /// (so the preview never shows misleading fake names).
    private var landlordPreviewName: String {
        let name = landlord?.fullName ?? ""
        return name.isEmpty ? "NOMBRE ARRENDADOR" : name
    }

    private var landlordPreviewDni: String {
        let dni = landlord?.dni ?? ""
        return dni.isEmpty ? "DNI ARRENDADOR" : dni
    }

    private var renderedPreview: AttributedString {
        var preview =
            templateText
            .replacingOccurrences(of: "{{tenant_name}}", with: "Ana García López")
            .replacingOccurrences(of: "{{tenant_dni}}", with: "12345678A")
            .replacingOccurrences(of: "{{tenant_address}}", with: property.address)
            .replacingOccurrences(of: "{{landlord_name}}", with: landlordPreviewName)
            .replacingOccurrences(of: "{{landlord_dni}}", with: landlordPreviewDni)
            .replacingOccurrences(of: "{{property_address}}", with: property.address)
            .replacingOccurrences(of: "{{room_name}}", with: "Habitación 1")
            .replacingOccurrences(of: "{{habitacion}}", with: "Habitación 1")
            .replacingOccurrences(of: "{{start_date}}", with: "1 de enero de 2025")
            .replacingOccurrences(of: "{{end_date}}", with: "31 de diciembre de 2025")
            .replacingOccurrences(of: "{{rent}}", with: "750€")
            .replacingOccurrences(of: "{{deposit}}", with: "1.500€")
            .replacingOccurrences(of: "{{deposit_words}}", with: "MIL QUINIENTOS EUROS")
            .replacingOccurrences(
                of: "{{date}}", with: Date().formatted(date: .long, time: .omitted))

        for variable in customVariables {
            preview = preview.replacingOccurrences(of: variable.templateKey, with: variable.defaultValue)
        }

        // Unfilled placeholders → blank fill-in line (matches the generated PDF)
        preview = preview.replacingOccurrences(
            of: "\\{\\{[^}]*\\}\\}", with: "______________", options: .regularExpression)

        if let attributed = try? AttributedString(
            markdown: preview,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(preview)
    }

    // MARK: - Data

    private func loadTemplate() async {
        isLoading = true
        let raw: String
        if let fresh = try? await appState.propertyService.fetchProperty(id: propertyId) {
            raw = fresh.contractTemplate ?? ""
        } else {
            raw = property.contractTemplate ?? ""
        }
        templateText = Self.migrateLegacyVariables(raw)
        isLoading = false
    }

    /// Converts old single-brace camelCase variables to the current {{snake_case}} format.
    static func migrateLegacyVariables(_ text: String) -> String {
        let migrations: [String: String] = [
            "{tenantName}": "{{tenant_name}}",
            "{tenantDni}": "{{tenant_dni}}",
            "{tenantCurrentAddress}": "{{tenant_address}}",
            "{landlordName}": "{{landlord_name}}",
            "{landlordDni}": "{{landlord_dni}}",
            "{propertyAddress}": "{{property_address}}",
            "{startDateShort}": "{{start_date}}",
            "{endDateShort}": "{{end_date}}",
            "{monthlyRent}": "{{rent}}",
            "{depositAmount}": "{{deposit}}",
            "{depositAmountWords}": "{{deposit_words}}",
            "{currentDate}": "{{date}}",
        ]
        var result = text
        for (old, new) in migrations {
            result = result.replacingOccurrences(of: old, with: new)
        }
        return result
    }
}

// MARK: - Full-screen editor sheet

struct ContractEditorSheet: View {
    let propertyId: UUID
    @Binding var property: Property
    let initialText: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var templateText: String = ""
    @State private var isSaving = false
    @State private var showSaved = false
    @State private var errorMessage: String?
    @State private var showLoadGlobalConfirmation = false
    @State private var showVariablesSheet = false
    @State private var showPDFPreview = false

    private let textViewRef = ContractTextEditor.TextViewRef()
    @State private var customVariables: [ContractVariable] = []

    private var variables: [(key: String, icon: String, displayName: String)] {
        var all: [(key: String, icon: String, displayName: String)] = ContractVariable.builtIn.map { ($0.key, $0.icon, $0.label) }
        for v in customVariables {
            all.append((v.templateKey, "chevron.left.forwardslash.chevron.right", v.label))
        }
        return all
    }

    var body: some View {
        VStack(spacing: 0) {
            // Editor — takes all available space
            ContractTextEditor(text: $templateText, isEditable: true, textViewRef: textViewRef)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Variable insertion bar — rises with the keyboard automatically
            variableBar
        }
        .navigationTitle(
            String(
                localized: "Editar contrato", locale: LanguageService.currentLocale,
                comment: "Title for contract editor sheet")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(
                    String(
                        localized: "Cancelar", locale: LanguageService.currentLocale,
                        comment: "Cancel button")
                ) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showPDFPreview = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .disabled(templateText.isEmpty)
                .accessibilityLabel(String(localized: "Vista previa del contrato", locale: LanguageService.currentLocale, comment: "Preview contract PDF action"))
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else if showSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text(
                            String(
                                localized: "Guardar", locale: LanguageService.currentLocale,
                                comment: "Save button")
                        )
                        .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showLoadGlobalConfirmation = true
                } label: {
                    Label(
                        String(
                            localized: "Cargar plantilla global",
                            locale: LanguageService.currentLocale,
                            comment: "Load global template button"),
                        systemImage: "arrow.down.doc"
                    )
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showVariablesSheet = true
                } label: {
                    Label(
                        String(
                            localized: "Gestionar variables",
                            locale: LanguageService.currentLocale,
                            comment: "Manage contract variables button"),
                        systemImage: "chevron.left.forwardslash.chevron.right"
                    )
                }
            }
        }
        .onAppear { templateText = initialText }
        .task { customVariables = (try? await ContractVariableService().fetchVariables()) ?? [] }
        .confirmationDialog(
            String(
                localized: "¿Cargar plantilla global?", locale: LanguageService.currentLocale,
                comment: "Confirmation title"),
            isPresented: $showLoadGlobalConfirmation
        ) {
            Button(
                String(
                    localized: "Cargar y reemplazar", locale: LanguageService.currentLocale,
                    comment: "Confirm load global"), role: .destructive
            ) {
                Task { await loadGlobalTemplate() }
            }
        } message: {
            Text(
                String(
                    localized: "Se reemplazará la plantilla actual por la global.",
                    locale: LanguageService.currentLocale, comment: "Confirmation message"))
        }
        .sheet(isPresented: $showVariablesSheet) {
            Task { customVariables = (try? await ContractVariableService().fetchVariables()) ?? [] }
        } content: {
            NavigationStack {
                ContractVariablesView()
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showPDFPreview) {
            NavigationStack {
                ContractPreviewView(property: property, templateOverride: templateText)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .errorAlert($errorMessage)
    }

    // MARK: - Variable bar

    @ViewBuilder
    private var variableBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(
                    String(
                        localized: "Insertar variable", locale: LanguageService.currentLocale,
                        comment: "Variable bar label")
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                Spacer()
                Button {
                    showVariablesSheet = true
                } label: {
                    Image(systemName: "gear")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(String(localized: "Gestionar variables", locale: LanguageService.currentLocale, comment: "Accessibility label for manage variables button"))
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        ContractTextEditor(text: $templateText, textViewRef: textViewRef)
                            .insertAtCursor("______________")
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.dashed").font(.caption)
                            Text(String(localized: "Campo en blanco", locale: LanguageService.currentLocale, comment: "Insert a blank fill-in field"))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                    }

                    ForEach(variables, id: \.key) { variable in
                        Button {
                            ContractTextEditor(text: $templateText, textViewRef: textViewRef)
                                .insertAtCursor(variable.key)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: variable.icon).font(.caption)
                                Text(variable.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Actions

    private func save() async {
        isSaving = true
        do {
            try await appState.propertyService.updateContractTemplate(
                propertyId: propertyId, template: templateText)
            var updated = property
            updated.contractTemplate = templateText
            property = updated
            showSaved = true
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch {
            errorMessage = error.safeUserMessage
        }
        isSaving = false
    }

    private func loadGlobalTemplate() async {
        do {
            templateText = try await ContractTemplateService().getTemplate()
        } catch {
            errorMessage = error.safeUserMessage
        }
    }
}
