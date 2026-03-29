import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor @Observable
final class DocumentListViewModel {
    var documents: [Document] = []
    var isLoading = false
    private(set) var isLoaded = false
    var errorMessage: String?        // Only for fetch errors (shows full-screen)
    var uploadError: String?         // For upload errors (shows as alert)
    var isUploading = false

    private let documentService: DocumentServiceProtocol
    private let propertyId: UUID
    private let tenantId: UUID?
    private let userId: UUID

    init(
        documentService: DocumentServiceProtocol,
        userId: UUID,
        propertyId: UUID,
        tenantId: UUID? = nil
    ) {
        self.documentService = documentService
        self.userId = userId
        self.propertyId = propertyId
        self.tenantId = tenantId
    }

    func fetchDocuments() async {
        guard !isLoaded else { return }
        isLoading = true
        errorMessage = nil
        do {
            if let tenantId {
                documents = try await documentService.fetchDocuments(tenantId: tenantId)
            } else {
                documents = try await documentService.fetchDocuments(propertyId: propertyId)
            }
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isLoading = false
            return
        } catch {
            errorMessage = String(localized: "Error loading documents: \(error.localizedDescription)", locale: LanguageService.currentLocale, comment: "Error message when documents fail to load")
        }
        if errorMessage == nil { isLoaded = true }
        isLoading = false
    }

    func refresh() async {
        isLoaded = false
        await fetchDocuments()
    }

    func uploadDocument(url: URL, onSuccess: @escaping () -> Void) async {
        isUploading = true
        uploadError = nil
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(
                    domain: "com.rentalmngr", code: 403,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "Could not access the file", locale: LanguageService.currentLocale, comment: "Error when file access is denied")])
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            let contentType = ext == "pdf" ? "application/pdf" : "image/jpeg"  // Simple fallback

            let newDoc = try await documentService.uploadDocument(
                data: data,
                name: name,
                fileType: contentType,
                propertyId: propertyId,
                tenantId: tenantId,
                uploadedBy: userId
            )

            documents.insert(newDoc, at: 0)
            onSuccess()
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isUploading = false
            return
        } catch {
            uploadError = String(localized: "Error uploading document: \(error.localizedDescription)", locale: LanguageService.currentLocale, comment: "Error message when document upload fails")
        }
        isUploading = false
    }

    func uploadScannedDocument(data: Data, name: String) async {
        isUploading = true
        uploadError = nil
        do {
            let newDoc = try await documentService.uploadDocument(
                data: data,
                name: name,
                fileType: "application/pdf",
                propertyId: propertyId,
                tenantId: tenantId,
                uploadedBy: userId
            )
            documents.insert(newDoc, at: 0)
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isUploading = false
            return
        } catch {
            uploadError = String(localized: "Error uploading document: \(error.localizedDescription)", locale: LanguageService.currentLocale, comment: "Error message when document upload fails")
        }
        isUploading = false
    }

    func deleteDocument(_ document: Document) async {
        do {
            try await documentService.deleteDocument(document)
            documents.removeAll { $0.id == document.id }
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            return
        } catch {
            errorMessage = String(localized: "Error deleting document: \(error.localizedDescription)", locale: LanguageService.currentLocale, comment: "Error message when document deletion fails")
        }
    }

    func getDocumentURL(_ document: Document) -> URL? {
        try? documentService.getDocumentURL(document)
    }
}
