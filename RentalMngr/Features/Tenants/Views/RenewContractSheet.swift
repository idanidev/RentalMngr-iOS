import SwiftUI

struct RenewContractSheet: View {
    let tenant: Tenant
    let onRenew: (Int) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMonths: Int
    @State private var isRenewing = false
    @State private var errorMessage: String?

    private let options: [(Int, String)] = [
        (1,  "1 mes"),
        (3,  "3 meses"),
        (6,  "6 meses"),
        (12, "12 meses (1 año)"),
        (24, "24 meses (2 años)"),
    ]

    init(tenant: Tenant, onRenew: @escaping (Int) async throws -> Void) {
        self.tenant = tenant
        self.onRenew = onRenew
        let validOptions = [1, 3, 6, 12, 24]
        let initial = tenant.contractMonths.flatMap { validOptions.contains($0) ? $0 : nil } ?? 6
        _selectedMonths = State(initialValue: initial)
    }

    // MARK: - Computed dates

    /// New start = day after current contract end. Falls back to today if nil.
    private var newStartDate: Date {
        let base = tenant.contractEndDate ?? Date()
        return Calendar.current.date(byAdding: .day, value: 1, to: base) ?? base
    }

    /// New end = newStartDate + selectedMonths, last day of that month.
    private var newEndDate: Date {
        var comps = DateComponents(month: selectedMonths)
        let added = Calendar.current.date(byAdding: comps, to: newStartDate) ?? newStartDate
        // Last day of the resulting month
        let range = Calendar.current.range(of: .day, in: .month, for: added)!
        comps = Calendar.current.dateComponents([.year, .month], from: added)
        comps.day = range.count
        return Calendar.current.date(from: comps) ?? added
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Tenant header
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tenant.fullName)
                                .font(.headline)
                            Text(String(localized: "Contract renewal", locale: LanguageService.currentLocale, comment: "Subtitle in renew contract sheet"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Current contract
                Section(String(localized: "Current Contract", locale: LanguageService.currentLocale, comment: "Section header for current contract dates")) {
                    dateRow(
                        label: String(localized: "Start", locale: LanguageService.currentLocale, comment: "Contract start date label"),
                        date: tenant.contractStartDate
                    )
                    dateRow(
                        label: String(localized: "End", locale: LanguageService.currentLocale, comment: "Contract end date label"),
                        date: tenant.contractEndDate
                    )
                }

                // Duration picker
                Section(String(localized: "Renewal Duration", locale: LanguageService.currentLocale, comment: "Section header for renewal duration picker")) {
                    Picker(
                        String(localized: "Duration", locale: LanguageService.currentLocale, comment: "Duration picker label"),
                        selection: $selectedMonths
                    ) {
                        ForEach(options, id: \.0) { months, label in
                            Text(label).tag(months)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                // New dates preview
                Section(String(localized: "New Contract", locale: LanguageService.currentLocale, comment: "Section header for new contract date preview")) {
                    dateRow(
                        label: String(localized: "New Start", locale: LanguageService.currentLocale, comment: "New contract start date label"),
                        date: newStartDate,
                        accent: true
                    )
                    dateRow(
                        label: String(localized: "New End", locale: LanguageService.currentLocale, comment: "New contract end date label"),
                        date: newEndDate,
                        accent: true
                    )
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(String(localized: "Renew Contract", locale: LanguageService.currentLocale, comment: "Navigation title for renew contract sheet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await renew() }
                    } label: {
                        if isRenewing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(String(localized: "Renew", locale: LanguageService.currentLocale, comment: "Confirm renew button"))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isRenewing)
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func dateRow(label: String, date: Date?, accent: Bool = false) -> some View {
        LabeledContent(label) {
            Text(date.map { $0.formatted(date: .long, time: .omitted) } ?? "—")
                .foregroundStyle(accent ? .orange : .primary)
                .fontWeight(accent ? .semibold : .regular)
        }
    }

    private func renew() async {
        isRenewing = true
        errorMessage = nil
        do {
            try await onRenew(selectedMonths)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isRenewing = false
    }
}
