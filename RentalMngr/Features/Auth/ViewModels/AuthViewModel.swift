import Foundation

@MainActor @Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var isSignUpMode = false
    var showResetPassword = false

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    var isFormValid: Bool {
        let emailValid = email.isValidEmail
        let passwordValid = password.count >= 6
        if isSignUpMode {
            return emailValid && passwordValid && password == confirmPassword
        }
        return emailValid && passwordValid
    }

    func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signUp(
                email: email.trimmingCharacters(in: .whitespaces), password: password)
            successMessage = String(localized: "Account created. Check your email to confirm.", locale: LanguageService.currentLocale, comment: "Success message after sign up")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func resetPassword() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.resetPassword(email: email.trimmingCharacters(in: .whitespaces))
            successMessage = String(localized: "Recovery email sent. Check your inbox.", locale: LanguageService.currentLocale, comment: "Success message after password reset request")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
