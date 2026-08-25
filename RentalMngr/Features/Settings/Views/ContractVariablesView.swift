import SwiftUI

struct ContractVariablesView: View {
    @State private var customVariables: [ContractVariable] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddSheet = false
    @State private var variableToEdit: ContractVariable?
    @State private var pendingAction: DestructiveAction?

    private let service = ContractVariableService()

    var body: some View {
        List {
            // Explanation
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        String(localized: "Cómo funcionan", locale: LanguageService.currentLocale),
                        systemImage: "info.circle.fill"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)

                    Text(String(localized: "Las variables son campos que se rellenan automáticamente en tus contratos. Escribe el nombre de la variable entre llaves dobles en tu plantilla y se sustituirá por su valor al generar el PDF.", locale: LanguageService.currentLocale))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Example
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Ejemplo:", locale: LanguageService.currentLocale))
                            .font(.caption.bold())
                        HStack(spacing: 4) {
                            Text("Plantilla:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\"La clave del WiFi es {{wifi}}\"")
                                .font(.caption2)
                                .monospaced()
                        }
                        HStack(spacing: 4) {
                            Text("Resultado:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\"La clave del WiFi es MiClave2024\"")
                                .font(.caption2)
                                .monospaced()
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.vertical, 4)
            }

            // Built-in variables
            Section {
                ForEach(ContractVariable.builtIn, id: \.key) { variable in
                    builtInRow(variable)
                }
            } header: {
                Text(String(localized: "Automáticas", locale: LanguageService.currentLocale))
            } footer: {
                Text(String(localized: "Estas se rellenan solas con los datos del inquilino, propiedad y arrendador. No se pueden modificar.", locale: LanguageService.currentLocale))
            }

            // Custom variables
            Section {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else if customVariables.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text(String(localized: "Aún no tienes variables propias", locale: LanguageService.currentLocale))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Crea una para añadir datos personalizados a tus contratos, como la clave WiFi, normas específicas, datos bancarios, etc.", locale: LanguageService.currentLocale))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        Button {
                            showAddSheet = true
                        } label: {
                            Label(
                                String(localized: "Crear variable", locale: LanguageService.currentLocale),
                                systemImage: "plus"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(customVariables) { variable in
                        customRow(variable)
                            .contentShape(Rectangle())
                            .onTapGesture { variableToEdit = variable }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingAction = deleteConfirmation(for: variable)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                Button {
                                    variableToEdit = variable
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }
            } header: {
                HStack {
                    Text(String(localized: "Tus variables", locale: LanguageService.currentLocale))
                    Spacer()
                    if !customVariables.isEmpty {
                        Text("\(customVariables.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                if !customVariables.isEmpty {
                    Text(String(localized: "Toca una variable para editarla. Desliza a la izquierda para eliminar. Los contratos ya generados no cambian.", locale: LanguageService.currentLocale))
                }
            }
        }
        .navigationTitle(
            String(localized: "Variables de contrato", locale: LanguageService.currentLocale)
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            Task { await loadVariables() }
        } content: {
            NavigationStack {
                ContractVariableFormView(variable: nil) { newVar in
                    customVariables.append(newVar)
                }
            }
        }
        .sheet(item: $variableToEdit) { variable in
            NavigationStack {
                ContractVariableFormView(variable: variable) { updated in
                    if let idx = customVariables.firstIndex(where: { $0.id == updated.id }) {
                        customVariables[idx] = updated
                    }
                }
            }
        }
        .destructiveConfirmation($pendingAction)
        .task { await loadVariables() }
        .errorAlert($errorMessage)
    }

    private func deleteConfirmation(for variable: ContractVariable) -> DestructiveAction {
        DestructiveAction(
            title: String(localized: "¿Borrar \(variable.templateKey)?", locale: LanguageService.currentLocale, comment: "Delete contract variable title"),
            message: String(localized: "Las plantillas que la usen dejarán de rellenarla. Los contratos ya generados no cambian.", locale: LanguageService.currentLocale, comment: "Delete contract variable message"),
            confirmLabel: String(localized: "Borrar variable", locale: LanguageService.currentLocale, comment: "Confirm delete contract variable"),
            icon: "curlybraces",
            perform: { await deleteVariable(variable) })
    }

    // MARK: - Rows

    private func builtInRow(_ variable: (key: String, icon: String, label: String)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: variable.icon)
                .font(.subheadline)
                .foregroundStyle(.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(variable.label)
                    .font(.subheadline)
                Text(variable.key)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .monospaced()
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func customRow(_ variable: ContractVariable) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.subheadline)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(variable.label)
                    .font(.subheadline)
                Text(variable.templateKey)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .monospaced()
            }

            Spacer()

            if !variable.defaultValue.isEmpty {
                Text(variable.defaultValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .trailing)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Data

    private func loadVariables() async {
        isLoading = true
        do {
            customVariables = try await service.fetchVariables()
        } catch where error.isCancellation || Task.isCancelled {
            isLoading = false
            return
        } catch {
            errorMessage = error.safeUserMessage
        }
        isLoading = false
    }

    private func deleteVariable(_ variable: ContractVariable) async {
        do {
            try await service.deleteVariable(id: variable.id)
            customVariables.removeAll { $0.id == variable.id }
        } catch {
            errorMessage = error.safeUserMessage
        }
    }
}
