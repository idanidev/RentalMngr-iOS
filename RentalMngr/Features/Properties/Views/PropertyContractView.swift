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
                                localized: "Edit", locale: LanguageService.currentLocale,
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
                    localized: "No contract template", locale: LanguageService.currentLocale,
                    comment: "Empty state title for contract tab"),
                systemImage: "doc.text"
            )
        } description: {
            Text(
                String(
                    localized: "Tap Edit to write the contract template for this property.",
                    locale: LanguageService.currentLocale,
                    comment: "Empty state description for contract tab"))
        } actions: {
            if canEdit {
                Button {
                    showEditor = true
                } label: {
                    Text(
                        String(
                            localized: "Edit template", locale: LanguageService.currentLocale,
                            comment: "Empty state action button"))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Rendered preview with placeholder values

    private var renderedPreview: AttributedString {
        let preview =
            templateText
            .replacingOccurrences(of: "{{tenant_name}}", with: "Ana García López")
            .replacingOccurrences(of: "{{tenant_dni}}", with: "12345678A")
            .replacingOccurrences(of: "{{tenant_address}}", with: property.address)
            .replacingOccurrences(of: "{{landlord_name}}", with: "Carlos Martínez")
            .replacingOccurrences(of: "{{landlord_dni}}", with: "87654321B")
            .replacingOccurrences(of: "{{property_address}}", with: property.address)
            .replacingOccurrences(of: "{{start_date}}", with: "1 de enero de 2025")
            .replacingOccurrences(of: "{{end_date}}", with: "31 de diciembre de 2025")
            .replacingOccurrences(of: "{{rent}}", with: "750€")
            .replacingOccurrences(of: "{{deposit}}", with: "1.500€")
            .replacingOccurrences(of: "{{deposit_words}}", with: "MIL QUINIENTOS EUROS")
            .replacingOccurrences(
                of: "{{date}}", with: Date().formatted(date: .long, time: .omitted))

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

    private let textViewRef = ContractTextEditor.TextViewRef()

    private let variables: [(key: String, icon: String, displayName: String)] = [
        ("{{tenant_name}}", "person", "Nombre inquilino (tenant name)"),
        ("{{tenant_dni}}", "creditcard", "DNI inquilino (tenant ID)"),
        ("{{tenant_address}}", "house", "Domicilio inquilino (tenant address)"),
        ("{{landlord_name}}", "person.badge.key", "Nombre arrendador (landlord name)"),
        ("{{landlord_dni}}", "creditcard.fill", "DNI arrendador (landlord ID)"),
        ("{{property_address}}", "mappin", "Dirección inmueble (property address)"),
        ("{{start_date}}", "calendar", "Inicio contrato (start date)"),
        ("{{end_date}}", "calendar.badge.checkmark", "Fin contrato (end date)"),
        ("{{rent}}", "eurosign", "Renta mensual (rent)"),
        ("{{deposit}}", "banknote", "Depósito (deposit)"),
        ("{{deposit_words}}", "textformat.123", "Depósito en letras (deposit words)"),
        ("{{date}}", "clock", "Fecha (date)"),
    ]

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
                localized: "Edit Contract", locale: LanguageService.currentLocale,
                comment: "Title for contract editor sheet")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(
                    String(
                        localized: "Cancel", locale: LanguageService.currentLocale,
                        comment: "Cancel button")
                ) {
                    dismiss()
                }
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
                                localized: "Save", locale: LanguageService.currentLocale,
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
                            localized: "Load global template",
                            locale: LanguageService.currentLocale,
                            comment: "Load global template button"),
                        systemImage: "arrow.down.doc"
                    )
                }
            }
        }
        .onAppear { templateText = initialText }
        .confirmationDialog(
            String(
                localized: "Load global template?", locale: LanguageService.currentLocale,
                comment: "Confirmation title"),
            isPresented: $showLoadGlobalConfirmation
        ) {
            Button(
                String(
                    localized: "Load and replace", locale: LanguageService.currentLocale,
                    comment: "Confirm load global"), role: .destructive
            ) {
                Task { await loadGlobalTemplate() }
            }
        } message: {
            Text(
                String(
                    localized: "This will replace the current template with the global one.",
                    locale: LanguageService.currentLocale, comment: "Confirmation message"))
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
                        localized: "Insert variable", locale: LanguageService.currentLocale,
                        comment: "Variable bar label")
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func loadGlobalTemplate() async {
        do {
            templateText = try await ContractTemplateService().getTemplate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
