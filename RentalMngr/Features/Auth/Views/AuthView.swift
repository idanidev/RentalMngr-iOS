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
                    Text("Rental Manager")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(vm.isSignUpMode ? "Crear cuenta" : "Iniciar sesión")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: Binding(get: { vm.email }, set: { vm.email = $0 }))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Contraseña", text: Binding(get: { vm.password }, set: { vm.password = $0 }))
                        .textContentType(vm.isSignUpMode ? .newPassword : .password)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    if vm.isSignUpMode {
                        SecureField("Confirmar contraseña", text: Binding(get: { vm.confirmPassword }, set: { vm.confirmPassword = $0 }))
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
                                Text(vm.isSignUpMode ? "Crear cuenta" : "Iniciar sesión")
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
                            Text("¿Olvidaste tu contraseña?")
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
                        Text(vm.isSignUpMode ? "¿Ya tienes cuenta? Iniciar sesión" : "¿No tienes cuenta? Regístrate")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
