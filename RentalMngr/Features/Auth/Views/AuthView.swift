import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: AuthViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel {
                authContent(viewModel)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AuthViewModel(authService: appState.authService)
            }
        }
    }

    @ViewBuilder
    private func authContent(_ vm: AuthViewModel) -> some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                    Text(String(localized: "Rental Manager", locale: LanguageService.currentLocale, comment: "App name on login screen"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(vm.isSignUpMode ? String(localized: "Create Account", locale: LanguageService.currentLocale, comment: "Auth subtitle when in sign up mode") : String(localized: "Sign In", locale: LanguageService.currentLocale, comment: "Auth subtitle when in sign in mode"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 16) {
                    TextField(String(localized: "Email", locale: LanguageService.currentLocale, comment: "Email field placeholder"), text: Binding(get: { vm.email }, set: { vm.email = $0 }))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    SecureField(String(localized: "Password", locale: LanguageService.currentLocale, comment: "Password field placeholder"), text: Binding(get: { vm.password }, set: { vm.password = $0 }))
                        .textContentType(vm.isSignUpMode ? .newPassword : .password)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    if vm.isSignUpMode {
                        SecureField(String(localized: "Confirm Password", locale: LanguageService.currentLocale, comment: "Confirm password field placeholder"), text: Binding(get: { vm.confirmPassword }, set: { vm.confirmPassword = $0 }))
                            .textContentType(.newPassword)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)

                // Error / Success messages
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let success = vm.successMessage {
                    Text(success)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Actions
                VStack(spacing: 12) {
                    Button {
                        Task {
                            if vm.isSignUpMode {
                                await vm.signUp()
                            } else {
                                await vm.signIn()
                            }
                        }
                    } label: {
                        Group {
                            if vm.isLoading {
                                ProgressView()
                            } else {
                                Text(vm.isSignUpMode ? String(localized: "Create Account", locale: LanguageService.currentLocale, comment: "Sign up button label") : String(localized: "Sign In", locale: LanguageService.currentLocale, comment: "Sign in button label"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.isFormValid || vm.isLoading)

                    if !vm.isSignUpMode {
                        NavigationLink {
                            ResetPasswordView()
                        } label: {
                            Text(String(localized: "Forgot your password?", locale: LanguageService.currentLocale, comment: "Forgot password link"))
                                .font(.subheadline)
                        }
                    }

                    Button {
                        withAnimation {
                            vm.isSignUpMode.toggle()
                            vm.errorMessage = nil
                            vm.successMessage = nil
                        }
                    } label: {
                        Text(vm.isSignUpMode ? String(localized: "Already have an account? Sign In", locale: LanguageService.currentLocale, comment: "Toggle to sign in mode") : String(localized: "Don't have an account? Sign Up", locale: LanguageService.currentLocale, comment: "Toggle to sign up mode"))
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
