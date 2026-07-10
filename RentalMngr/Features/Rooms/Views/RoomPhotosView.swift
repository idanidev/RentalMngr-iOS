import Foundation
import SwiftUI

struct RoomPhotosView: View {
    @Environment(AppState.self) private var appState
    let photos: [String]
    @State private var selectedIndex = 0

    var body: some View {
        Group {
            if photos.isEmpty {
                ContentUnavailableView(
                    String(localized: "No photos", locale: LanguageService.currentLocale,
                           comment: "Empty state title for photos view"),
                    systemImage: "photo.slash"
                )
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(photos.indices, id: \.self) { index in
                        AsyncImageView(bucket: SupabaseConfig.storageBucket, path: photos[index], contentMode: .fit)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .onAppear {
                    if selectedIndex >= photos.count {
                        selectedIndex = max(0, photos.count - 1)
                    }
                }
            }
        }
        .navigationTitle(
            String(localized: "Photos (\(photos.count))", locale: LanguageService.currentLocale,
                   comment: "Navigation title for photos view showing count"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
