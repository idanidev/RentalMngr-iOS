import SwiftUI

struct RoomPhotosView: View {
    @Environment(AppState.self) private var appState
    let photos: [String]
    @State private var selectedIndex = 0

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, path in
                AsyncImage(url: try? appState.storageService.getPublicURL(path: path)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .navigationTitle("Fotos")
        .navigationBarTitleDisplayMode(.inline)
    }
}
