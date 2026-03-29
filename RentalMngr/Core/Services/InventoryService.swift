import Foundation
import Supabase
import os

protocol InventoryServiceProtocol: Sendable {
    func fetchInventory(roomId: UUID) async throws -> [InventoryItem]
    func createItem(_ item: InventoryItemOrphan) async throws -> InventoryItem
    func updateItem(_ item: InventoryItem) async throws -> InventoryItem
    func deleteItem(id: UUID) async throws
}

struct InventoryItemOrphan: Codable, Sendable {
    let roomId: UUID
    let name: String
    let description: String?
    let condition: InventoryCondition
    let purchaseDate: Date?
    let purchasePrice: Decimal?
    let photos: [String]?

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case name
        case description
        case condition
        case purchaseDate = "purchase_date"
        case purchasePrice = "purchase_price"
        case photos
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(roomId, forKey: .roomId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(condition, forKey: .condition)
        try container.encodeIfPresent(purchaseDate, forKey: .purchaseDate)
        try container.encodeIfPresent(purchasePrice, forKey: .purchasePrice)
        try container.encodeIfPresent(photos, forKey: .photos)
    }
}

final class InventoryService: InventoryServiceProtocol {
    private let client = SupabaseService.shared.client
    private let logger = Logger(subsystem: "com.rentalmngr", category: "InventoryService")

    func fetchInventory(roomId: UUID) async throws -> [InventoryItem] {
        try await client
            .from(SupabaseTable.inventoryItems)
            .select()
            .eq("room_id", value: roomId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createItem(_ item: InventoryItemOrphan) async throws -> InventoryItem {
        try await client
            .from(SupabaseTable.inventoryItems)
            .insert(item)
            .select()
            .single()
            .execute()
            .value
    }

    func updateItem(_ item: InventoryItem) async throws -> InventoryItem {
        try await client
            .from(SupabaseTable.inventoryItems)
            .update(item)
            .eq("id", value: item.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteItem(id: UUID) async throws {
        try await client
            .from(SupabaseTable.inventoryItems)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
