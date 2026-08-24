import SwiftUI

struct PropertyFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PropertyFormViewModel?

    let property: Property?

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(property == nil ? String(localized: "New Property", locale: LanguageService.currentLocale, comment: "Navigation title for new property form") : String(localized: "Edit Property", locale: LanguageService.currentLocale, comment: "Navigation title for edit property form"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Cancel button")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save", locale: LanguageService.currentLocale, comment: "Save button")) {
                    Task {
                        if let _ = await viewModel?.save() {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel?.isFormValid != true || viewModel?.isLoading == true)
            }
        }
        .onAppear {
            if viewModel == nil {
                if let userId = appState.authService.currentUserId {
                    viewModel = PropertyFormViewModel(
                        propertyService: appState.propertyService,
                        utilityService: appState.utilityService,
                        userId: userId,
                        property: property
                    )
                }
            }
        }
        .task {
            // Load existing utility config when editing
            if property != nil {
                await viewModel?.loadUtilities()
            }
        }
    }

    @ViewBuilder
    private func formContent(_ vm: PropertyFormViewModel) -> some View {
        Form {
            Section(String(localized: "Information", locale: LanguageService.currentLocale, comment: "Property form section header")) {
                TextField(String(localized: "Name", locale: LanguageService.currentLocale, comment: "Property name field"), text: Binding(get: { vm.name }, set: { vm.name = $0 }))
                TextField(String(localized: "Address", locale: LanguageService.currentLocale, comment: "Property address field"), text: Binding(get: { vm.address }, set: { vm.address = $0 }))
                TextField(String(localized: "Description (optional)", locale: LanguageService.currentLocale, comment: "Property description field"), text: Binding(get: { vm.description }, set: { vm.description = $0 }), axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Toggle(
                    String(localized: "Se alquila entera", locale: LanguageService.currentLocale, comment: "Toggle: rent the whole property as one unit"),
                    isOn: Binding(get: { vm.isSingleUnit }, set: { vm.isSingleUnit = $0 })
                )
            } footer: {
                Text(vm.isSingleUnit
                    ? String(localized: "Un solo contrato para toda la vivienda. Cuenta como 1 unidad de tu plan aunque tenga varias habitaciones.", locale: LanguageService.currentLocale, comment: "Footer when single unit is on")
                    : String(localized: "Alquiler por habitaciones: cada habitación tiene su inquilino y cuenta como 1 unidad de tu plan.", locale: LanguageService.currentLocale, comment: "Footer when renting by room"))
            }

            // Utilities / Services configuration (community fees handled separately below)
            Section {
                ForEach(vm.utilities.indices, id: \.self) { index in
                    if vm.utilities[index].type != .communityFees {
                        utilityRow(vm: vm, index: index)
                    }
                }
            } header: {
                Text(String(localized: "Utilities", locale: LanguageService.currentLocale, comment: "Utilities section header in property form"))
            } footer: {
                Text(String(localized: "Select which utility services this property has to track their payments.", locale: LanguageService.currentLocale, comment: "Utilities section description"))
                    .font(.caption2)
            }

            // Community fees — a flat fee that REPLACES tracking individual utilities.
            if let cfIndex = vm.utilities.firstIndex(where: { $0.type == .communityFees }) {
                Section {
                    Toggle(isOn: Binding(
                        get: { vm.utilities[cfIndex].enabled },
                        set: { vm.utilities[cfIndex].enabled = $0 }
                    )) {
                        Label {
                            Text(String(localized: "Use a flat monthly fee", locale: LanguageService.currentLocale, comment: "Toggle to enable community fees instead of individual utilities"))
                        } icon: {
                            Image(systemName: UtilityType.communityFees.icon)
                                .foregroundStyle(UtilityType.communityFees.color)
                        }
                    }
                    if vm.utilities[cfIndex].enabled {
                        CommunityServicesEditor(
                            amount: Binding(
                                get: { vm.utilities[cfIndex].amountText },
                                set: { vm.utilities[cfIndex].amountText = $0 }
                            ),
                            services: Binding(
                                get: { vm.utilities[cfIndex].includedServices },
                                set: { vm.utilities[cfIndex].includedServices = $0 }
                            ))
                    }
                } header: {
                    Text(UtilityType.communityFees.displayName)
                } footer: {
                    Text(String(localized: "A flat fee that replaces tracking individual utilities. Set the amount and what it includes.", locale: LanguageService.currentLocale, comment: "Footer explaining community fees replace individual utilities"))
                        .font(.caption2)
                }
            }

        }
        .loadingOverlay(vm.isLoading)
        .errorAlert(Binding(
            get: { vm.errorMessage },
            set: { vm.errorMessage = $0 }))
    }

    @ViewBuilder
    private func utilityRow(vm: PropertyFormViewModel, index: Int) -> some View {
        let utility = vm.utilities[index]

        Toggle(isOn: Binding(
            get: { vm.utilities[index].enabled },
            set: { vm.utilities[index].enabled = $0 }
        )) {
            Label {
                Text(utility.type.displayName)
            } icon: {
                Image(systemName: utility.type.icon)
                    .foregroundStyle(utility.type.color)
            }
        }
    }
}

// MARK: - Community fees "includes" chips editor

private struct CommunityServicesEditor: View {
    @Binding var amount: String
    @Binding var services: [String]
    @State private var customText = ""

    private var suggestions: [String] {
        [
            UtilityType.electricity.displayName,
            UtilityType.water.displayName,
            UtilityType.gas.displayName,
            UtilityType.heating.displayName,
            UtilityType.internet.displayName,
            UtilityType.trash.displayName,
            String(localized: "Cleaning", locale: LanguageService.currentLocale, comment: "Community fees included service: cleaning"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "Monthly amount", locale: LanguageService.currentLocale, comment: "Community fees monthly amount label"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("0", text: $amount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                Text("€").foregroundStyle(.secondary)
            }

            Text(String(localized: "These common expenses include:", locale: LanguageService.currentLocale, comment: "Label above community fees included-services chips"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !services.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(services, id: \.self) { item in
                        chip(item, selected: true) { services.removeAll { $0 == item } }
                    }
                }
            }

            let remaining = suggestions.filter { !services.contains($0) }
            if !remaining.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(remaining, id: \.self) { item in
                        chip(item, selected: false) { services.append(item) }
                    }
                }
            }

            HStack {
                TextField(
                    String(localized: "Add another service…", locale: LanguageService.currentLocale, comment: "Placeholder to add a custom community fees service"),
                    text: $customText)
                    .textInputAutocapitalization(.sentences)
                    .onSubmit { addCustom() }
                Button { addCustom() } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(customText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(text).font(.caption)
                Image(systemName: selected ? "xmark" : "plus")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                selected ? Color.teal.opacity(0.18) : Color.secondary.opacity(0.12),
                in: Capsule())
            .foregroundStyle(selected ? Color.teal : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func addCustom() {
        let trimmed = customText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !services.contains(trimmed) else { customText = ""; return }
        services.append(trimmed)
        customText = ""
    }
}

// MARK: - Simple wrapping layout for chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
