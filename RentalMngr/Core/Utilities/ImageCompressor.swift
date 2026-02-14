import UIKit

enum ImageCompressor {
    static func compress(_ data: Data, maxSizeKB: Int = 500, maxDimension: CGFloat = 1920) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        // Resize if necessary
        let resized = resize(image, maxDimension: maxDimension)

        // Compress with decreasing quality
        var compression: CGFloat = 0.85
        var compressedData = resized.jpegData(compressionQuality: compression)

        while let data = compressedData, data.count > maxSizeKB * 1024, compression > 0.1 {
            compression -= 0.1
            compressedData = resized.jpegData(compressionQuality: compression)
        }

        return compressedData
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }

        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
