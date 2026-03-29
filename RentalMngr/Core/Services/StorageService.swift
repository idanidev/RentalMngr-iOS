import Foundation
import Supabase

final class StorageService: StorageServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Generic Storage

    func uploadFile(
        bucket: String, path: String, data: Data, contentType: String
    ) async throws -> String {
        try await client.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: contentType,
                    upsert: true
                )
            )
        return path
    }

    func getPublicURL(bucket: String, path: String) throws -> URL {
        try client.storage
            .from(bucket)
            .getPublicURL(path: path)
    }

    func deleteFile(bucket: String, path: String) async throws {
        try await client.storage
            .from(bucket)
            .remove(paths: [path])
    }

    // MARK: - Legacy / Photos

    func uploadPhoto(propertyId: UUID, roomId: UUID, imageData: Data, index: Int) async throws
        -> String
    {
        let path = "\(propertyId)/\(roomId)/\(UUID().uuidString).jpg"
        return try await uploadFile(
            bucket: SupabaseConfig.storageBucket,
            path: path,
            data: imageData,
            contentType: "image/jpeg"
        )
    }

    func getPublicURL(path: String) throws -> URL {
        try getPublicURL(bucket: SupabaseConfig.storageBucket, path: path)
    }

    func deletePhoto(path: String) async throws {
        try await deleteFile(bucket: SupabaseConfig.storageBucket, path: path)
    }

    func deletePhotos(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        try await client.storage
            .from(SupabaseConfig.storageBucket)
            .remove(paths: paths)
    }
}
