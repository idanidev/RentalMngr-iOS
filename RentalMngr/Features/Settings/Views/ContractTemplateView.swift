import SwiftUI

struct ContractTemplateView: View {
    @Environment(AppState.self) private var appState
    @State private var templateText: String = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSaved = false
    @State private var errorMessage: String?
    @State private var selectedTab: ContractEditorTab = .editor

    private let templateService = ContractTemplateService()
    private let textViewRef = ContractTextEditor.TextViewRef()

    private var variables: [(key: String, icon: String, displayName: String)] {
        [
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
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(ContractEditorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == .editor {
                editorView
            } else {
                previewView
            }
        }
        .navigationTitle(
            String(
                localized: "Contract Template", locale: LanguageService.currentLocale,
                comment: "Title for contract template editor")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
        }
        .task { await loadTemplate() }
        .errorAlert($errorMessage)
    }

    // MARK: - Editor tab

    @ViewBuilder
    private var editorView: some View {
        VStack(spacing: 0) {
            ContractTextEditor(text: $templateText, textViewRef: textViewRef)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            variableBar
        }
    }

    @ViewBuilder
    private var variableBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(
                    String(
                        localized: "Insert variable", locale: LanguageService.currentLocale,
                        comment: "Label for variable insertion bar")
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
                                Image(systemName: variable.icon)
                                    .font(.caption)
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

    // MARK: - Preview tab

    @ViewBuilder
    private var previewView: some View {
        if templateText.isEmpty {
            ContentUnavailableView(
                String(
                    localized: "No template yet", locale: LanguageService.currentLocale,
                    comment: "Empty preview state title"),
                systemImage: "doc.text",
                description: Text(
                    String(
                        localized: "Write a contract template in the editor to preview it here.",
                        locale: LanguageService.currentLocale, comment: "Empty preview description")
                )
            )
        } else {
            ScrollView {
                Text(renderedPreview)
                    .font(.body)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Helpers

    private var renderedPreview: AttributedString {
        let preview =
            templateText
            .replacingOccurrences(of: "{{tenant_name}}", with: "Ana García López")
            .replacingOccurrences(of: "{{tenant_dni}}", with: "12345678A")
            .replacingOccurrences(of: "{{tenant_address}}", with: "Calle Mayor 1, Madrid")
            .replacingOccurrences(of: "{{landlord_name}}", with: "Carlos Martínez")
            .replacingOccurrences(of: "{{landlord_dni}}", with: "87654321B")
            .replacingOccurrences(of: "{{property_address}}", with: "Calle Gran Vía 10, Madrid")
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
        errorMessage = nil
        do {
            templateText = try await templateService.getTemplate()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await templateService.saveTemplate(templateText)
            showSaved = true
            try? await Task.sleep(for: .seconds(2))
            showSaved = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
