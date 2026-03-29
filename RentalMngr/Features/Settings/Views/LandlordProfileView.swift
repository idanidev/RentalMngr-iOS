import SwiftUI

struct LandlordProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var profile: LandlordProfile = .empty
    @State private var showSaved = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    TextField(
                        String(localized: "Full Name", locale: LanguageService.currentLocale, comment: "Placeholder for landlord full name field"),
                        text: $profile.fullName
                    )
                    .textContentType(.name)
                } label: {
                    Text(String(localized: "Name", locale: LanguageService.currentLocale, comment: "Label for landlord name field"))
                }

                LabeledContent {
                    TextField(
                        String(localized: "ID Number (DNI / NIE)", locale: LanguageService.currentLocale, comment: "Placeholder for landlord ID number field"),
                        text: $profile.dni
                    )
                    .textInputAutocapitalization(.characters)
                } label: {
                    Text(String(localized: "ID Number", locale: LanguageService.currentLocale, comment: "Label for landlord ID number field"))
                }
            } header: {
                Text(String(localized: "Identification", locale: LanguageService.currentLocale, comment: "Section header for landlord identification fields"))
            } footer: {
                Text(String(localized: "This information will appear on generated contracts.", locale: LanguageService.currentLocale, comment: "Footer explaining that profile data is used in contracts"))
            }

            Section(String(localized: "Address", locale: LanguageService.currentLocale, comment: "Section header for landlord address")) {
                TextField(
                    String(localized: "Full Address", locale: LanguageService.currentLocale, comment: "Placeholder for landlord full address field"),
                    text: $profile.address,
                    axis: .vertical
                )
                .textContentType(.fullStreetAddress)
                .lineLimit(2...4)
            }

            Section(String(localized: "Contact", locale: LanguageService.currentLocale, comment: "Section header for landlord contact information")) {
                LabeledContent {
                    TextField(
                        String(localized: "Email", locale: LanguageService.currentLocale, comment: "Placeholder for landlord email field"),
                        text: $profile.email
                    )
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                } label: {
                    Text(String(localized: "Email", locale: LanguageService.currentLocale, comment: "Label for landlord email field"))
                }

                LabeledContent {
                    TextField(
                        String(localized: "Phone (Optional)", locale: LanguageService.currentLocale, comment: "Placeholder for optional landlord phone field"),
                        text: Binding(
                            get: { profile.phone ?? "" },
                            set: { profile.phone = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                } label: {
                    Text(String(localized: "Phone", locale: LanguageService.currentLocale, comment: "Label for landlord phone number field"))
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(String(localized: "Landlord Profile", locale: LanguageService.currentLocale, comment: "Navigation title for landlord profile screen"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                profile = try await appState.userProfileService.getLandlordProfile()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else if showSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text(String(localized: "Save", locale: LanguageService.currentLocale, comment: "Button to save landlord profile"))
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving)
            }
        }
    }

    private func save() async {
        // Validate required fields
        guard !profile.fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = String(localized: "Name is required.", locale: LanguageService.currentLocale, comment: "Validation error for missing name")
            return
        }
        guard !profile.dni.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = String(localized: "ID number is required.", locale: LanguageService.currentLocale, comment: "Validation error for missing DNI")
            return
        }
        errorMessage = nil
        isSaving = true
        do {
            try await appState.userProfileService.saveLandlordProfile(profile)
            showSaved = true
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
