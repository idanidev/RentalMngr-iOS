import SwiftUI
import PhotosUI

struct PhotoPickerView: View {
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var images: [Data]
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Fotos (\(images.count)/\(maxCount))")
                    .font(.headline)
                Spacer()
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: maxCount - images.count,
                    matching: .images
                ) {
                    Label("Añadir", systemImage: "photo.badge.plus")
                        .font(.subheadline)
                }
                .disabled(images.count >= maxCount)
            }

            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            if let uiImage = UIImage(data: images[index]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            images.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white, .red)
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        if let compressed = ImageCompressor.compress(data) {
                            if images.count < maxCount {
                                images.append(compressed)
                            }
                        }
                    }
                }
                selectedItems.removeAll()
            }
        }
    }
}
