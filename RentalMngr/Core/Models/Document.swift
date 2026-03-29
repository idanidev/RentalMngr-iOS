import Foundation

struct Document: Identifiable, Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let name: String
    let fileType: String
    let filePath: String
    let propertyId: UUID?
    let tenantId: UUID?
    let uploadedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case name
        case fileType = "file_type"
        case filePath = "file_path"
        case propertyId = "property_id"
        case tenantId = "tenant_id"
        case uploadedBy = "uploaded_by"
    }
}
