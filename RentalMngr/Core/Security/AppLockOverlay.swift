import SwiftUI

struct AppLockOverlay: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)

                Text("RentalMngr")
                    .font(.title2.bold())

                Text(String(localized: "La app está bloqueada", locale: LanguageService.currentLocale))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await appState.appLockManager.unlock() }
                } label: {
                    Label(
                        String(localized: "Desbloquear con \(appState.appLockManager.biometryTypeName)", locale: LanguageService.currentLocale),
                        systemImage: "faceid"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
            }
        }
        .task {
            await appState.appLockManager.unlock()
        }
    }
}
