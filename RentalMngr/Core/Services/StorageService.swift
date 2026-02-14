import Foundation
import Supabase

final class StorageService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func uploadPhoto(propertyId: UUID, roomId: UUID, imageData: Data, index: Int) async throws -> String {
        let path = "\(propertyId)/\(roomId)/\(UUID().uuidString).jpg"
        try await client.storage
            .from(SupabaseConfig.storageBucket)
            .upload(
                path,
                data: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
        return path
    }

    func getPublicURL(path: String) throws -> URL {
        try client.storage
            .from(SupabaseConfig.storageBucket)
            .getPublicURL(path: path)
    }

    func deletePhoto(path: String) async throws {
        try await client.storage
            .from(SupabaseConfig.storageBucket)
            .remove(paths: [path])
    }

    func deletePhotos(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        try await client.storage
            .from(SupabaseConfig.storageBucket)
            .remove(paths: paths)
    }
}
