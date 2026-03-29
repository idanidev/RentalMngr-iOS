import Foundation
import Supabase

final class DocumentService: DocumentServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }
    private let storageService: StorageServiceProtocol

    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }

    func fetchDocuments(propertyId: UUID) async throws -> [Document] {
        try await client
            .from(SupabaseTable.documents)
            .select()
            .eq("property_id", value: propertyId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchDocuments(tenantId: UUID) async throws -> [Document] {
        try await client
            .from(SupabaseTable.documents)
            .select()
            .eq("tenant_id", value: tenantId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func uploadDocument(
        data: Data, name: String, fileType: String, propertyId: UUID, tenantId: UUID?,
        uploadedBy: UUID
    ) async throws -> Document {
        // 1. Upload to Storage
        let ext = fileType == "application/pdf" ? "pdf" : "jpg"  // Simple extension logic
        let path = "\(propertyId)/\(UUID().uuidString).\(ext)"

        _ = try await storageService.uploadFile(
            bucket: SupabaseConfig.documentsBucket,
            path: path,
            data: data,
            contentType: fileType
        )

        // 2. Insert into Database
        struct NewDocument: Encodable {
            let name: String
            let file_type: String
            let file_path: String
            let property_id: UUID
            let tenant_id: UUID?
            let uploaded_by: UUID
        }

        let newDoc = NewDocument(
            name: name,
            file_type: fileType,
            file_path: path,
            property_id: propertyId,
            tenant_id: tenantId,
            uploaded_by: uploadedBy
        )

        let document: Document =
            try await client
            .from(SupabaseTable.documents)
            .insert(newDoc)
            .select()
            .single()
            .execute()
            .value

        return document
    }

    func deleteDocument(_ document: Document) async throws {
        // 1. Delete from Storage
        try await storageService.deleteFile(
            bucket: SupabaseConfig.documentsBucket,
            path: document.filePath
        )

        // 2. Delete from Database
        try await client
            .from(SupabaseTable.documents)
            .delete()
            .eq("id", value: document.id)
            .execute()
    }

    func getDocumentURL(_ document: Document) throws -> URL {
        try storageService.getPublicURL(
            bucket: SupabaseConfig.documentsBucket, path: document.filePath)
    }
}
