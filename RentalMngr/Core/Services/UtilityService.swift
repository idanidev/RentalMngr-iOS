import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "UtilityService")

final class UtilityService: UtilityServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    /// Join select for utility charges with room and tenant info
    private let chargeSelect =
        "*, room:room_id(id, name, tenant_name, tenant:tenant_id(full_name))"

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Property Utility Configuration

    func fetchPropertyUtilities(propertyId: UUID) async throws -> [PropertyUtility] {
        try await client
            .from(SupabaseTable.propertyUtilities)
            .select()
            .eq("property_id", value: propertyId)
            .order("utility_type")
            .execute()
            .value
    }

    func savePropertyUtilities(
        propertyId: UUID, utilities: [PropertyUtilityUpsert]
    ) async throws {
        let enabledTypes = utilities.map(\.utility_type)

        // Only delete utility types that are no longer enabled — never delete everything first
        let idsToDelete = enabledTypes.isEmpty ? ["__none__"] : enabledTypes
        try await client
            .from(SupabaseTable.propertyUtilities)
            .delete()
            .eq("property_id", value: propertyId)
            .not("utility_type", operator: .in, value: idsToDelete)
            .execute()

        // Upsert enabled utilities (insert or update on conflict)
        guard !utilities.isEmpty else { return }

        try await client
            .from(SupabaseTable.propertyUtilities)
            .upsert(utilities, onConflict: "property_id,utility_type")
            .execute()

        logger.debug("Saved \(utilities.count) utility configs for property \(propertyId)")
    }

    // MARK: - Utility Charges

    func fetchUtilityCharges(
        propertyId: UUID, startDate: Date?, endDate: Date?, limit: Int?, offset: Int?
    ) async throws -> [UtilityCharge] {
        var query =
            client
            .from(SupabaseTable.utilityCharges)
            .select(chargeSelect)
            .eq("property_id", value: propertyId)

        if let startDate {
            let dateStr = iso8601.string(from: startDate)
            query = query.gte("month", value: dateStr)
        }
        if let endDate {
            let dateStr = iso8601.string(from: endDate)
            query = query.lte("month", value: dateStr)
        }

        var builder = query.order("month", ascending: false)

        if let limit, let offset {
            builder = builder.range(from: offset, to: offset + limit - 1)
        }

        return try await builder.execute().value
    }

    func markUtilityPaid(chargeId: UUID) async throws {
        struct PaidUpdate: Encodable {
            let paid = true
            let payment_date: Date
        }
        try await client
            .from(SupabaseTable.utilityCharges)
            .update(PaidUpdate(payment_date: Date()))
            .eq("id", value: chargeId)
            .execute()
    }

    func markUtilityUnpaid(chargeId: UUID) async throws {
        struct UnpaidUpdate: Encodable {
            let paid = false
            let payment_date: Date? = nil
        }
        try await client
            .from(SupabaseTable.utilityCharges)
            .update(UnpaidUpdate())
            .eq("id", value: chargeId)
            .execute()
    }

    func createUtilityCharge(
        propertyId: UUID, roomId: UUID, utilityType: String,
        amount: Decimal, month: Date
    ) async throws -> UtilityCharge {
        struct NewCharge: Encodable {
            let property_id: UUID
            let room_id: UUID
            let utility_type: String
            let amount: Decimal
            let month: Date
        }
        return
            try await client
            .from(SupabaseTable.utilityCharges)
            .insert(
                NewCharge(
                    property_id: propertyId,
                    room_id: roomId,
                    utility_type: utilityType,
                    amount: amount,
                    month: month
                )
            )
            .select(chargeSelect)
            .single()
            .execute()
            .value
    }

    func deleteUtilityCharge(id: UUID) async throws {
        try await client
            .from(SupabaseTable.utilityCharges)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Fetch utility charges for ALL given properties in a date range (for global finances view)
    func fetchAllUtilityCharges(
        propertyIds: [UUID], startDate: Date, endDate: Date
    ) async throws -> [UtilityCharge] {
        guard !propertyIds.isEmpty else { return [] }
        let startStr = iso8601.string(from: startDate)
        let endStr = iso8601.string(from: endDate)

        return
            try await client
            .from(SupabaseTable.utilityCharges)
            .select(chargeSelect)
            .in("property_id", values: propertyIds.map(\.uuidString))
            .gte("month", value: startStr)
            .lte("month", value: endStr)
            .order("month", ascending: false)
            .execute()
            .value
    }

    // MARK: - Auto-generation of Monthly Utility Charges

    /// Generate utility charges for the current month for all properties.
    /// For each property with configured utilities, creates charges for each occupied room
    /// if they don't already exist for the current month.
    func generateMonthlyUtilityCharges(properties: [Property]) async throws {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components) else { return }

        for property in properties {
            do {
                // 1. Get utility configs for this property
                let configs = try await fetchPropertyUtilities(propertyId: property.id)
                guard !configs.isEmpty else { continue }

                // 2. Get occupied rooms
                let occupiedRooms = property.occupiedPrivateRooms
                guard !occupiedRooms.isEmpty else { continue }

                // 3. Check existing charges for this month to avoid duplicates
                let endOfMonth =
                    calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth)
                    ?? now
                let existingCharges = try await fetchUtilityCharges(
                    propertyId: property.id,
                    startDate: startOfMonth,
                    endDate: endOfMonth,
                    limit: nil,
                    offset: nil
                )

                // Build a set of existing (roomId, utilityType) for fast lookup
                let existingKeys = Set(existingCharges.map { "\($0.roomId)_\($0.utilityType)" })

                // 4. Create missing charges
                for room in occupiedRooms {
                    for config in configs {
                        let key = "\(room.id)_\(config.utilityType)"
                        guard !existingKeys.contains(key) else { continue }

                        let amount = config.monthlyAmount ?? Decimal.zero

                        _ = try await createUtilityCharge(
                            propertyId: property.id,
                            roomId: room.id,
                            utilityType: config.utilityType,
                            amount: amount,
                            month: startOfMonth
                        )
                    }
                }
            } catch {
                logger.error("Error generating utility charges for \(property.name): \(error)")
            }
        }
    }
}

/// Encodable struct for upserting property utility configuration
struct PropertyUtilityUpsert: Encodable, Sendable {
    let property_id: UUID
    let utility_type: String
    let included_in_rent: Bool
    let monthly_amount: Decimal?
}
