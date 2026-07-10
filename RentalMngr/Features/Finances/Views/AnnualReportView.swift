import SwiftUI

// MARK: - Model

/// Per-property income/expense roll-up for a single tax year.
struct PropertyAnnualSummary: Identifiable, Sendable {
    let id: UUID
    let name: String
    let collected: Decimal   // income marked as paid
    let pending: Decimal     // income not yet paid
    let expenses: Decimal
    var net: Decimal { collected - expenses }
}

// MARK: - ViewModel

@MainActor @Observable
final class AnnualReportViewModel {
    var year: Int
    private(set) var rows: [PropertyAnnualSummary] = []
    private(set) var isLoading = false
    var errorMessage: String?

    var totalCollected: Decimal { rows.reduce(.zero) { $0 + $1.collected } }
    var totalPending: Decimal { rows.reduce(.zero) { $0 + $1.pending } }
    var totalExpenses: Decimal { rows.reduce(.zero) { $0 + $1.expenses } }
    var totalNet: Decimal { totalCollected - totalExpenses }

    /// Last 6 years for the picker.
    var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 5)...current).reversed()
    }

    private let financeService: FinanceServiceProtocol
    private let propertyService: PropertyServiceProtocol

    init(
        financeService: FinanceServiceProtocol, propertyService: PropertyServiceProtocol,
        year: Int? = nil
    ) {
        self.financeService = financeService
        self.propertyService = propertyService
        self.year = year ?? Calendar.current.component(.year, from: Date())
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard
            let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
            let end = cal.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return }

        do {
            let properties = try await propertyService.fetchProperties()
            guard !properties.isEmpty else { rows = []; return }
            let ids = properties.map(\.id)

            // All income for the year in one query, grouped by property.
            let income = try await financeService.fetchAllIncome(
                propertyIds: ids, startDate: start, endDate: end)
            let incomeByProperty = Dictionary(grouping: income, by: \.propertyId)

            var result: [PropertyAnnualSummary] = []
            for property in properties {
                let propIncome = incomeByProperty[property.id] ?? []
                let collected = propIncome.filter(\.paid).reduce(Decimal.zero) { $0 + $1.amount }
                let pending = propIncome.filter { !$0.paid }.reduce(Decimal.zero) { $0 + $1.amount }
                let expenses = try await financeService.fetchExpenses(
                    propertyId: property.id, startDate: start, endDate: end,
                    limit: nil, offset: nil
                ).reduce(Decimal.zero) { $0 + $1.amount }

                // Skip properties with no movements this year.
                if collected == 0 && pending == 0 && expenses == 0 { continue }
                result.append(
                    PropertyAnnualSummary(
                        id: property.id, name: property.name, collected: collected,
                        pending: pending, expenses: expenses))
            }
            rows = result.sorted { $0.net > $1.net }
        } catch {
            if error.isCancellation || Task.isCancelled { return }
            errorMessage = error.safeUserMessage
        }
    }
}

// MARK: - View

struct AnnualReportView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: AnnualReportViewModel
    @State private var pdfURL: URL?

    init(appState: AppState, year: Int? = nil) {
        _viewModel = State(
            initialValue: AnnualReportViewModel(
                financeService: appState.financeService,
                propertyService: appState.propertyService,
                year: year))
    }

    var body: some View {
        List {
            Section {
                Picker(
                    String(localized: "Año", locale: LanguageService.currentLocale, comment: "Year picker label"),
                    selection: $viewModel.year
                ) {
                    ForEach(viewModel.availableYears, id: \.self) { y in
                        Text(verbatim: String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.year) { _, _ in
                    Task { await viewModel.load() }
                }
            }

            if viewModel.isLoading {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
            } else if viewModel.rows.isEmpty {
                Section {
                    ContentUnavailableView(
                        String(localized: "Sin movimientos", locale: LanguageService.currentLocale, comment: "Empty annual report title"),
                        systemImage: "tray",
                        description: Text(String(localized: "No hay ingresos ni gastos registrados en \(String(viewModel.year)).", locale: LanguageService.currentLocale, comment: "Empty annual report subtitle")))
                }
            } else {
                Section(String(localized: "Por propiedad", locale: LanguageService.currentLocale, comment: "Per-property section header")) {
                    ForEach(viewModel.rows) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(row.name).font(.headline)
                            amountRow(label: String(localized: "Cobrado", locale: LanguageService.currentLocale, comment: "Collected income"), value: row.collected, color: .green)
                            if row.pending > 0 {
                                amountRow(label: String(localized: "Pendiente", locale: LanguageService.currentLocale, comment: "Pending income"), value: row.pending, color: .orange)
                            }
                            amountRow(label: String(localized: "Gastos", locale: LanguageService.currentLocale, comment: "Expenses"), value: row.expenses, color: .red)
                            Divider()
                            amountRow(label: String(localized: "Neto", locale: LanguageService.currentLocale, comment: "Net"), value: row.net, color: row.net >= 0 ? .primary : .red, bold: true)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(String(localized: "Total \(String(viewModel.year))", locale: LanguageService.currentLocale, comment: "Annual total section header")) {
                    amountRow(label: String(localized: "Total cobrado", locale: LanguageService.currentLocale, comment: "Total collected"), value: viewModel.totalCollected, color: .green)
                    if viewModel.totalPending > 0 {
                        amountRow(label: String(localized: "Total pendiente", locale: LanguageService.currentLocale, comment: "Total pending"), value: viewModel.totalPending, color: .orange)
                    }
                    amountRow(label: String(localized: "Total gastos", locale: LanguageService.currentLocale, comment: "Total expenses"), value: viewModel.totalExpenses, color: .red)
                    amountRow(label: String(localized: "Resultado neto", locale: LanguageService.currentLocale, comment: "Net result"), value: viewModel.totalNet, color: viewModel.totalNet >= 0 ? .primary : .red, bold: true)
                }
            }
        }
        .navigationTitle(String(localized: "Informe anual", locale: LanguageService.currentLocale, comment: "Annual report nav title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let pdfURL {
                    ShareLink(item: pdfURL) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel(String(localized: "Compartir", locale: LanguageService.currentLocale, comment: "Accessibility label for share button"))
                } else {
                    Button {
                        Task { await exportPDF() }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(String(localized: "Compartir", locale: LanguageService.currentLocale, comment: "Accessibility label for share button"))
                    .disabled(viewModel.rows.isEmpty)
                }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.year) { _, _ in pdfURL = nil }
        .onDisappear {
            if let pdfURL { try? FileManager.default.removeItem(at: pdfURL) }
        }
        .errorAlert(Binding(
            get: { viewModel.errorMessage },
            set: { viewModel.errorMessage = $0 }))
    }

    @ViewBuilder
    private func amountRow(label: String, value: Decimal, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.bold() : .subheadline)
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value.formatted(currencyCode: "EUR", showDecimals: true))
                .font(bold ? .subheadline.bold() : .subheadline)
                .foregroundStyle(color)
        }
    }

    private func exportPDF() async {
        let data = await PDFGenerator().generateAnnualReport(
            year: viewModel.year, rows: viewModel.rows,
            totalCollected: viewModel.totalCollected, totalPending: viewModel.totalPending,
            totalExpenses: viewModel.totalExpenses, totalNet: viewModel.totalNet)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Informe_\(viewModel.year).pdf")
        // Only point the share sheet at the file if the write actually succeeded.
        do {
            try data.write(to: url)
            pdfURL = url
        } catch {
            pdfURL = nil
        }
    }
}
