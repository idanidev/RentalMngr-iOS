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

            // Utilities / Services configuration
            Section {
                ForEach(vm.utilities.indices, id: \.self) { index in
                    utilityRow(vm: vm, index: index)
                }
            } header: {
                Text(String(localized: "Utilities", locale: LanguageService.currentLocale, comment: "Utilities section header in property form"))
            } footer: {
                Text(String(localized: "Select which utility services this property has to track their payments.", locale: LanguageService.currentLocale, comment: "Utilities section description"))
                    .font(.caption2)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .loadingOverlay(vm.isLoading)
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
