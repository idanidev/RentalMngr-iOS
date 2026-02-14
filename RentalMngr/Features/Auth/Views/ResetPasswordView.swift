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

            Text("Recuperar contraseña")
                .font(.title2)
                .fontWeight(.bold)

            Text("Introduce tu email y te enviaremos un enlace para restablecer tu contraseña.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Email", text: $email)
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
                        message = "Email enviado. Revisa tu bandeja de entrada."
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
                        Text("Enviar enlace")
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
        .navigationTitle("Recuperar contraseña")
        .navigationBarTitleDisplayMode(.inline)
    }
}
