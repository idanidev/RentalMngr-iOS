import SwiftUI

struct LoadingView: View {
    var message: String = String(localized: "Loading...", locale: LanguageService.currentLocale, comment: "Default loading message")

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
