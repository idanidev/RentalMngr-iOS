import SwiftUI

/// Historial de subidas de renta de un inquilino, dentro de su ficha (#24).
struct RentHistorySection: View {
    @Environment(AppState.self) private var appState
    let tenant: Tenant
    /// Se llama después de registrar una subida: la renta del inquilino ha
    /// cambiado y la ficha tiene que recargarla.
    let onRentChanged: () async -> Void

    @State private var changes: [RentChange] = []
    @State private var loadFailed = false
    @State private var showRegister = false

    var body: some View {
        Section {
            if loadFailed {
                // En línea y sin alerta: se carga cada vez que se abre la ficha,
                // y una alerta por cada visita sería peor que el fallo.
                Label(String(localized: "No se ha podido cargar el historial.",
                        locale: LanguageService.currentLocale, comment: "Rent history load error"),
                    systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if changes.isEmpty {
                Text(String(localized: "Todavía no hay subidas registradas.",
                    locale: LanguageService.currentLocale, comment: "Rent history empty"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(changes) { change in
                RentChangeRow(change: change)
            }

            if tenant.active {
                Button {
                    showRegister = true
                } label: {
                    Label(String(localized: "Registrar subida",
                            locale: LanguageService.currentLocale, comment: "Button to register a rent change"),
                        systemImage: "arrow.up.right.circle")
                }
            }
        } header: {
            Text(String(localized: "Historial de renta", locale: LanguageService.currentLocale,
                comment: "Rent history section header"))
        }
        .task(id: tenant.id) { await load() }
        .sheet(isPresented: $showRegister) {
            NavigationStack {
                RegisterRentChangeSheet(tenant: tenant) {
                    await load()
                    await onRentChanged()
                }
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
    }

    private func load() async {
        do {
            changes = try await appState.rentChangeService.fetchChanges(tenantId: tenant.id)
            loadFailed = false
        } catch where error.isCancellation {
            return
        } catch {
            loadFailed = true
        }
    }
}

/// Una fila del historial: fecha, de cuánto a cuánto y la nota.
private struct RentChangeRow: View {
    let change: RentChange

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(change.effectiveDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                if let note = change.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(importes)
                    .font(.subheadline)
                    .monospacedDigit()
                if let pct = change.percentChange {
                    Text((pct / 100).formatted(
                        .percent.precision(.fractionLength(1)).sign(strategy: .always())))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        // Para quien cobra, subir es lo esperado; bajar se marca.
                        .foregroundStyle(pct >= 0 ? .green : .orange)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var importes: String {
        let nuevo = change.newAmount.formatted(currencyCode: "EUR")
        guard let anterior = change.previousAmount else { return nuevo }
        return "\(anterior.formatted(currencyCode: "EUR")) → \(nuevo)"
    }
}

/// Formulario para registrar una subida.
struct RegisterRentChangeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let tenant: Tenant
    let onSaved: () async -> Void

    @State private var draft: RentChangeDraft
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(tenant: Tenant, onSaved: @escaping () async -> Void) {
        self.tenant = tenant
        self.onSaved = onSaved
        // Las subidas suelen regir desde el día 1 del mes siguiente.
        var draft = RentChangeDraft()
        let calendar = Calendar.current
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date()),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))
        {
            draft.effectiveDate = firstDay
        }
        _draft = State(initialValue: draft)
    }

    private var currentRent: Decimal? { tenant.effectiveMonthlyRent }
    private var problem: RentChangeDraft.Problem? { draft.problem(currentRent: currentRent) }

    var body: some View {
        Form {
            Section {
                LabeledContent(
                    String(localized: "Renta actual", locale: LanguageService.currentLocale,
                        comment: "Current rent label"),
                    value: currentRent?.formatted(currencyCode: "EUR")
                        ?? String(localized: "Sin renta", locale: LanguageService.currentLocale,
                            comment: "No rent set"))
            }

            Section {
                TextField(
                    String(localized: "Renta nueva", locale: LanguageService.currentLocale,
                        comment: "New rent amount field"),
                    text: $draft.amountText)
                    .keyboardType(.decimalPad)
                DatePicker(
                    String(localized: "Desde", locale: LanguageService.currentLocale,
                        comment: "Effective date of the new rent"),
                    selection: $draft.effectiveDate, displayedComponents: .date)
                TextField(
                    String(localized: "Nota (opcional)", locale: LanguageService.currentLocale,
                        comment: "Optional note for the rent change"),
                    text: $draft.note,
                    prompt: Text(String(localized: "Ej.: subida del IPC", locale: LanguageService.currentLocale,
                        comment: "Example note for a rent change")))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let resumen {
                        Text(resumen).font(.footnote.weight(.semibold))
                    }
                    if problem == .sameAsCurrent {
                        Text(String(localized: "Es la misma renta que ya tiene.",
                            locale: LanguageService.currentLocale, comment: "Same rent warning"))
                            .foregroundStyle(.orange)
                    }
                    Text(String(localized: "Se actualiza la renta y los cobros pendientes desde ese mes. Los que ya están cobrados no cambian.",
                        locale: LanguageService.currentLocale, comment: "What registering a rent change does"))
                }
            }
        }
        .navigationTitle(String(localized: "Registrar subida", locale: LanguageService.currentLocale,
            comment: "Register rent change title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancelar", locale: LanguageService.currentLocale,
                    comment: "Cancel button")) { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button(String(localized: "Guardar", locale: LanguageService.currentLocale,
                        comment: "Save button")) {
                        Task { await save() }
                    }
                    .disabled(problem != nil)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .errorAlert($errorMessage, context: "Registrar subida")
    }

    /// "400 € → 420 € (+5,0 %)", en cuanto hay un importe válido.
    private var resumen: String? {
        guard let nuevo = draft.amount, nuevo > 0 else { return nil }
        let destino = nuevo.formatted(currencyCode: "EUR")
        guard let actual = currentRent, actual > 0 else { return destino }
        let pct = NSDecimalNumber(decimal: (nuevo - actual) / actual).doubleValue
        let pctTexto = pct.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))
        return "\(actual.formatted(currencyCode: "EUR")) → \(destino) (\(pctTexto))"
    }

    private func save() async {
        guard problem == nil, let amount = draft.amount else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await appState.rentChangeService.recordChange(
                tenantId: tenant.id, newAmount: amount, effectiveDate: draft.effectiveDate,
                note: note.isEmpty ? nil : note)
            await onSaved()
            dismiss()
        } catch where error.isCancellation {
            return
        } catch {
            errorMessage = error.safeUserMessage
        }
    }
}
