import SwiftUI

/// Second step of password reset: user enters the 6-digit OTP received by email
/// and the new password. Calls `verifyPasswordResetOTP` and dismisses on success.
struct NewPasswordView: View {
    let email: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var token = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private var canSubmit: Bool {
        token.count == 6
            && newPassword.count >= 8
            && newPassword == confirmPassword
            && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 50))
                    .foregroundStyle(.tint)
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    Text(String(
                        localized: "Nueva contraseña",
                        locale: LanguageService.currentLocale,
                        comment: "New password screen title"))
                        .font(.title2).bold()
                    Text(String(
                        localized: "Introduce el código de 6 dígitos que enviamos a \(email) y tu nueva contraseña.",
                        locale: LanguageService.currentLocale,
                        comment: "New password instructions with email"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Código", locale: LanguageService.currentLocale, comment: "OTP code field label"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("000000", text: $token)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.title2.monospacedDigit())
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: token) { _, new in
                            token = String(new.filter(\.isNumber).prefix(6))
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Nueva contraseña", locale: LanguageService.currentLocale, comment: "New password field label"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    SecureField("········", text: $newPassword)
                        .textContentType(.newPassword)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Confirmar contraseña", locale: LanguageService.currentLocale, comment: "Confirm password field label"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    SecureField("········", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text(String(localized: "Las contraseñas no coinciden", locale: LanguageService.currentLocale, comment: "Mismatching password error"))
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    if !newPassword.isEmpty && newPassword.count < 8 {
                        Text(String(localized: "Mínimo 8 caracteres", locale: LanguageService.currentLocale, comment: "Password too short hint"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(String(localized: "Cambiar contraseña", locale: LanguageService.currentLocale, comment: "Submit password change button"))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(canSubmit ? Color.accentColor : Color.secondary.opacity(0.3),
                                in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(!canSubmit)

                Button {
                    Task {
                        do {
                            try await appState.authService.resetPassword(email: email)
                            errorMessage = nil
                        } catch {
                            errorMessage = error.safeUserMessage
                        }
                    }
                } label: {
                    Text(String(localized: "Reenviar código", locale: LanguageService.currentLocale, comment: "Resend OTP button"))
                        .font(.footnote)
                }
                .disabled(isLoading)
            }
            .padding(20)
        }
        .navigationTitle(String(localized: "Nueva contraseña", locale: LanguageService.currentLocale, comment: "Nav title for new password screen"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            String(localized: "Contraseña actualizada",
                   locale: LanguageService.currentLocale,
                   comment: "Success alert title"),
            isPresented: $showSuccess
        ) {
            Button("OK") { dismiss() }
        } message: {
            Text(String(localized: "Ya puedes iniciar sesión con tu nueva contraseña.",
                        locale: LanguageService.currentLocale,
                        comment: "Success alert body"))
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await appState.authService.verifyPasswordResetOTP(
                email: email.trimmingCharacters(in: .whitespaces),
                token: token,
                newPassword: newPassword
            )
            showSuccess = true
        } catch {
            errorMessage = error.safeUserMessage
        }
    }
}
