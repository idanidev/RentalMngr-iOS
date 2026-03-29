import Foundation
import Supabase

final class SharedExpenseService: SharedExpenseServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func fetchSharedExpenses(propertyId: UUID) async throws -> [SharedExpense] {
        try await client
            .from(SupabaseTable.sharedExpenses)
            .select()
            .eq("property_id", value: propertyId)
            .order("date", ascending: false)
            .execute()
            .value
    }

    func createSharedExpense(propertyId: UUID, title: String, description: String?, amount: Decimal,
                             category: SharedExpenseCategory, date: Date, splitType: SplitType,
                             createdBy: UUID) async throws -> SharedExpense {
        struct NewExpense: Encodable {
            let property_id: UUID
            let title: String
            let description: String?
            let amount: Decimal
            let category: String
            let date: Date
            let split_type: String
            let created_by: UUID
        }
        return try await client
            .from(SupabaseTable.sharedExpenses)
            .insert(NewExpense(property_id: propertyId, title: title, description: description,
                               amount: amount, category: category.rawValue, date: date,
                               split_type: splitType.rawValue, created_by: createdBy))
            .select()
            .single()
            .execute()
            .value
    }

    func deleteSharedExpense(id: UUID) async throws {
        try await client
            .from(SupabaseTable.sharedExpenses)
            .delete()
            .eq("id", value: id)
            .execute()
    }

}
