import Foundation
import Supabase

/// Resolves Supabase Storage object paths to signed, time-limited URLs and caches
/// them by a stable `bucket/path` key.
///
/// This lets the storage buckets stay PRIVATE (no anonymous `.../object/public/...`
/// access to tenant documents or room photos) while the app still displays them.
/// A signed URL embeds a token that changes on every sign, so callers must cache
/// by the stable path — never by the signed URL — or every render would miss the
/// cache. Entries are refreshed shortly before they expire.
actor SignedURLCache {
    static let shared = SignedURLCache()

    private struct Entry {
        let url: URL
        let expiry: Date
    }

    private var cache: [String: Entry] = [:]
    /// Signed-URL lifetime. Long enough to browse comfortably, short enough that a
    /// leaked link stops working.
    private let ttl: TimeInterval = 3600
    /// Refresh a bit before the real expiry so an in-flight load never uses a URL
    /// that expires mid-request.
    private let refreshMargin: TimeInterval = 120

    private var client: SupabaseClient { SupabaseService.shared.client }

    /// A valid signed URL for `bucket/path`, reusing a cached one when still fresh.
    func url(bucket: String, path: String, expiresIn: Int? = nil) async throws -> URL {
        let key = "\(bucket)/\(path)"
        if let entry = cache[key], entry.expiry.timeIntervalSinceNow > refreshMargin {
            return entry.url
        }
        let lifetime = expiresIn ?? Int(ttl)
        let signed = try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: lifetime)
        cache[key] = Entry(url: signed, expiry: Date().addingTimeInterval(TimeInterval(lifetime)))
        return signed
    }

    /// Firma en UNA sola petición todas las rutas que aún no estén en caché.
    ///
    /// Sin esto, abrir una propiedad con 6 habitaciones lanzaba 6 peticiones de
    /// firma antes de empezar a descargar ninguna imagen. Llamar a esto al
    /// entrar en la pantalla deja las URLs listas y cada foto va directa a
    /// descargar.
    func prefetch(bucket: String, paths: [String], expiresIn: Int? = nil) async {
        let lifetime = expiresIn ?? Int(ttl)
        let missing = paths.filter { path in
            guard let entry = cache["\(bucket)/\(path)"] else { return true }
            return entry.expiry.timeIntervalSinceNow <= refreshMargin
        }
        guard !missing.isEmpty else { return }

        do {
            let signed = try await client.storage
                .from(bucket)
                .createSignedURLs(paths: missing, expiresIn: lifetime)
            let expiry = Date().addingTimeInterval(TimeInterval(lifetime))
            for (path, url) in zip(missing, signed) {
                cache["\(bucket)/\(path)"] = Entry(url: url, expiry: expiry)
            }
        } catch {
            // Sin drama: cada imagen firmará por su cuenta al cargarse.
        }
    }

    /// Drop a cached entry (e.g. after the underlying object is replaced/deleted).
    func invalidate(bucket: String, path: String) {
        cache["\(bucket)/\(path)"] = nil
    }
}
