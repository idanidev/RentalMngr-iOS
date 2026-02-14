import Foundation

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var isSignUpMode = false
    var showResetPassword = false

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
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
            try await authService.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password)
            successMessage = "Cuenta creada. Revisa tu correo para confirmar."
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
            successMessage = "Email de recuperación enviado. Revisa tu correo."
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
