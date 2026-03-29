import SwiftUI

struct ResetPasswordView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.fill")
                .font(.system(size: 50))
                .foregroundStyle(.tint)

            Text(String(localized: "Reset Password", locale: LanguageService.currentLocale, comment: "Reset password screen title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(String(localized: "Enter your email and we'll send you a link to reset your password.", locale: LanguageService.currentLocale, comment: "Reset password instructions"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField(String(localized: "Email", locale: LanguageService.currentLocale, comment: "Email field placeholder"), text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(isError ? .red : .green)
            }

            Button {
                Task {
                    isLoading = true
                    do {
                        try await appState.authService.resetPassword(email: email.trimmingCharacters(in: .whitespaces))
                        message = String(localized: "Email sent. Check your inbox.", locale: LanguageService.currentLocale, comment: "Success message after password reset email sent")
                        isError = false
                    } catch {
                        message = error.localizedDescription
                        isError = true
                    }
                    isLoading = false
                }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(String(localized: "Send Link", locale: LanguageService.currentLocale, comment: "Send password reset link button"))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || isLoading)

            Spacer()
        }
        .padding()
        .navigationTitle(String(localized: "Reset Password", locale: LanguageService.currentLocale, comment: "Navigation title for reset password screen"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
