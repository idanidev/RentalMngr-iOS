import SwiftUI

struct ContractVariableFormView: View {
    @Environment(\.dismiss) private var dismiss
    let variable: ContractVariable?
    let onSave: (ContractVariable) -> Void

    @State private var name: String = ""
    @State private var label: String = ""
    @State private var defaultValue: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = ContractVariableService()
    private var isEditing: Bool { variable != nil }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isValid: Bool {
        !trimmedName.isEmpty
            && !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isValidName
    }

    private var isValidName: Bool {
        let regex = /^[a-z][a-z0-9_]*$/
        return trimmedName.wholeMatch(of: regex) != nil
    }

    /// Suggest examples based on common use cases
    private let suggestions: [(name: String, label: String, value: String)] = [
        ("wifi", "Clave WiFi", "MiRedWiFi2024"),
        ("iban", "IBAN del arrendador", "ES12 3456 7890 1234 5678 9012"),
        ("comunidad", "Cuota de comunidad", "45€/mes"),
        ("basura", "Día de basura", "Lunes y jueves"),
        ("portal_code", "Código del portal", "1234B"),
    ]

    var body: some View {
        Form {
            // Quick suggestions (only when creating)
            if !isEditing && name.isEmpty {
                Section {
                    ForEach(suggestions, id: \.name) { suggestion in
                        Button {
                            name = suggestion.name
                            label = suggestion.label
                            defaultValue = suggestion.value
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.label)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text("{{\(suggestion.name)}}")
                                        .font(.caption)
                                        .monospaced()
                                        .foregroundStyle(.blue)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "Sugerencias", locale: LanguageService.currentLocale))
                } footer: {
                    Text(String(localized: "Toca una sugerencia para usarla como base, o crea la tuya propia abajo", locale: LanguageService.currentLocale))
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Clave (identificador)", locale: LanguageService.currentLocale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("wifi", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .monospaced()
                        .disabled(isEditing)
                        .foregroundStyle(isEditing ? .secondary : .primary)
                }

                if !trimmedName.isEmpty && !isValidName {
                    Label(
                        String(localized: "Solo minúsculas, números y _. Debe empezar por letra.", locale: LanguageService.currentLocale),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Nombre visible", locale: LanguageService.currentLocale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Clave WiFi", text: $label)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Valor por defecto", locale: LanguageService.currentLocale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("MiRedWiFi2024", text: $defaultValue)
                }
            } header: {
                Text(String(localized: "Definición", locale: LanguageService.currentLocale))
            } footer: {
                if !trimmedName.isEmpty && isValidName {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "En tu plantilla de contrato escribe:", locale: LanguageService.currentLocale))
                        Text("  {{\(trimmedName)}}")
                            .monospaced()
                            .foregroundStyle(.blue)
                        Text(String(localized: "y se sustituirá por \"\(defaultValue.isEmpty ? "..." : defaultValue)\" al generar el PDF.", locale: LanguageService.currentLocale))
                    }
                }
            }

            // Live preview
            if isValid {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label)
                                    .font(.subheadline)
                                Text("{{\(trimmedName)}}")
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            if !defaultValue.isEmpty {
                                Text(defaultValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "En el contrato:", locale: LanguageService.currentLocale))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 0) {
                                Text("\"...la clave WiFi es ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(defaultValue.isEmpty ? "{{\(trimmedName)}}" : defaultValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(defaultValue.isEmpty ? .blue : .green)
                                Text("...\"")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(String(localized: "Vista previa", locale: LanguageService.currentLocale))
                }
            }
        }
        .navigationTitle(
            isEditing
                ? String(localized: "Editar variable", locale: LanguageService.currentLocale)
                : String(localized: "Nueva variable", locale: LanguageService.currentLocale)
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancelar", locale: LanguageService.currentLocale)) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Guardar", locale: LanguageService.currentLocale)) {
                    Task { await save() }
                }
                .disabled(!isValid || isSaving)
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            if let variable {
                name = variable.name
                label = variable.label
                defaultValue = variable.defaultValue
            }
        }
        .errorAlert($errorMessage)
    }

    private func save() async {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDefault = defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        do {
            if let existing = variable {
                var updated = existing
                updated.name = trimmedName
                updated.label = trimmedLabel
                updated.defaultValue = trimmedDefault
                try await service.updateVariable(updated)
                onSave(updated)
            } else {
                let created = try await service.createVariable(
                    name: trimmedName,
                    label: trimmedLabel,
                    defaultValue: trimmedDefault
                )
                onSave(created)
            }
            dismiss()
        } catch {
            errorMessage = error.safeUserMessage
        }
        isSaving = false
    }
}
