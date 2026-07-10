import SwiftUI

#if os(macOS)
    import AppKit
    typealias PlatformImage = NSImage
    extension Image {
        init(platformImage: PlatformImage) {
            self.init(nsImage: platformImage)
        }
    }
#else
    import UIKit
    typealias PlatformImage = UIImage
    extension Image {
        init(platformImage: PlatformImage) {
            self.init(uiImage: platformImage)
        }
    }
#endif

// MARK: - Image Cache

/// Thread-safe in-memory image cache using NSCache.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, PlatformImage>()
    private let lock = NSLock()

    private init() {
        cache.countLimit = 100  // Up to 100 images
        cache.totalCostLimit = 1024 * 1024 * 80  // 80 MB
    }

    func get(_ key: String) -> PlatformImage? {
        lock.withLock { cache.object(forKey: key as NSString) }
    }

    func set(_ image: PlatformImage, forKey key: String, cost: Int = 0) {
        lock.withLock { cache.setObject(image, forKey: key as NSString, cost: cost) }
    }
}

// MARK: - Dedicated URLSession for image loading

extension URLSession {
    /// Shared session for images: 6 concurrent connections per host, 30s timeout.
    fileprivate static let images: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 30
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20 MB HTTP cache
            diskCapacity: 100 * 1024 * 1024,  // 100 MB disk cache
            diskPath: "com.rentalmngr.imagecache"
        )
        return URLSession(configuration: config)
    }()
}

// MARK: - AsyncImageView

/// A view that loads an image asynchronously with proper task lifecycle management.
/// - Cancels in-flight download when the view disappears or the URL changes.
/// - Uses a dedicated URLSession with HTTP disk caching.
/// - Downscales to `targetSize` off the main thread via CGImageSource.
struct AsyncImageView: View {
    /// Where the image comes from: a ready URL, or a private-bucket object path
    /// that must be resolved to a signed URL on demand.
    private enum Source: Equatable {
        case url(URL?)
        case storage(bucket: String, path: String)
    }

    private let source: Source
    let contentMode: ContentMode
    let targetSize: CGSize?

    @State private var image: PlatformImage?
    @State private var isLoading = false

    init(url: URL?, contentMode: ContentMode = .fill, targetSize: CGSize? = nil) {
        self.source = .url(url)
        self.contentMode = contentMode
        self.targetSize = targetSize
    }

    /// Loads a private-bucket object by path, resolving a signed URL on demand and
    /// caching the decoded image by the stable `bucket/path` key (never the signed
    /// URL, whose token rotates on every sign).
    init(bucket: String, path: String, contentMode: ContentMode = .fill, targetSize: CGSize? = nil) {
        self.source = .storage(bucket: bucket, path: path)
        self.contentMode = contentMode
        self.targetSize = targetSize
    }

    /// Stable cache key independent of any signed-URL token.
    private var stableKey: String? {
        switch source {
        case .url(let u): return u?.absoluteString
        case .storage(let bucket, let path): return "\(bucket)/\(path)"
        }
    }

    var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
            } else {
                Color.gray.opacity(0.1)
            }
        }
        .task(id: source) {
            guard let stableKey else {
                image = nil
                isLoading = false
                return
            }

            let cacheKey =
                "\(stableKey)_\(Int(targetSize?.width ?? 0))x\(Int(targetSize?.height ?? 0))"

            // Serve from memory cache — no async work needed
            if let cached = ImageCache.shared.get(cacheKey) {
                image = cached
                isLoading = false
                return
            }

            image = nil
            isLoading = true
            defer { isLoading = false }

            // Resolve the actual URL to fetch — sign private-bucket paths on demand.
            let url: URL
            switch source {
            case .url(let u):
                guard let u else { return }
                url = u
            case .storage(let bucket, let path):
                guard let signed = try? await SignedURLCache.shared.url(bucket: bucket, path: path)
                else { return }
                url = signed
            }
            guard !Task.isCancelled else { return }

            let ts = targetSize
            #if os(iOS)
                let screenScale = UIScreen.main.scale
            #endif

            do {
                // 1. Network fetch — uses HTTP disk cache automatically
                let (data, _) = try await URLSession.images.data(from: url)
                guard !Task.isCancelled else { return }

                // 2. Decode + downscale off the main thread
                let platformImage: PlatformImage? = await Task.detached(priority: .userInitiated) {
                    #if os(iOS)
                        if let ts {
                            guard let source = CGImageSourceCreateWithData(data as CFData, nil)
                            else { return nil }
                            let maxDim = max(ts.width, ts.height) * screenScale
                            let options: [CFString: Any] = [
                                kCGImageSourceThumbnailMaxPixelSize: maxDim,
                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                kCGImageSourceCreateThumbnailWithTransform: true,
                                kCGImageSourceShouldCache: true,
                            ]
                            guard
                                let cgImage = CGImageSourceCreateThumbnailAtIndex(
                                    source, 0, options as CFDictionary)
                            else { return nil }
                            return UIImage(cgImage: cgImage)
                        } else {
                            return UIImage(data: data)
                        }
                    #else
                        return NSImage(data: data)
                    #endif
                }.value

                guard !Task.isCancelled, let platformImage else { return }

                // 3. Store in memory cache
                ImageCache.shared.set(platformImage, forKey: cacheKey, cost: data.count)

                // 4. Publish to UI
                image = platformImage
            } catch {
                // Swallow CancellationError and network errors silently — view shows placeholder
            }
        }
    }
}
