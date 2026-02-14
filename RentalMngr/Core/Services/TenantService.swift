import Foundation
import Supabase

nonisolated private struct AssignTenantParams: Encodable, Sendable {
    let p_tenant_id: UUID
    let p_room_id: UUID
}

nonisolated private struct UnassignTenantParams: Encodable, Sendable {
    let p_room_id: UUID
}

final class TenantService {
    private var client: SupabaseClient { SupabaseService.shared.client }

    /// The join select string matching the webapp
    private let tenantSelect =
        "*, room:rooms!rooms_tenant_id_fkey(id, name, monthly_rent, size_sqm, room_type)"

    /// Fetch tenants WITH their assigned room info (joined)
    func fetchTenants(propertyId: UUID) async throws -> [Tenant] {
        let response =
            try await client
            .from("tenants")
            .select(tenantSelect)
            .eq("property_id", value: propertyId)
            .order("active", ascending: false)
            .order("full_name")
            .execute()

        // Debug: print raw JSON response
        let rawJSON = String(data: response.data, encoding: .utf8) ?? "nil"
        print(
            "[TenantService] Raw response (\(response.data.count) bytes): \(rawJSON.prefix(2000))")

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                // Try ISO8601 with fractional seconds
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) { return date }
                // Try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) { return date }
                // Try date-only format (yyyy-MM-dd)
                let dateOnly = DateFormatter()
                dateOnly.dateFormat = "yyyy-MM-dd"
                dateOnly.locale = Locale(identifier: "en_US_POSIX")
                if let date = dateOnly.date(from: dateString) { return date }
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Cannot decode date: \(dateString)")
            }
            let tenants = try decoder.decode([Tenant].self, from: response.data)
            print("[TenantService] Successfully decoded \(tenants.count) tenants")
            return tenants
        } catch {
            print("[TenantService] DECODE ERROR: \(error)")
            throw error
        }
    }

    func fetchActiveTenants(propertyId: UUID) async throws -> [Tenant] {
        try await client
            .from("tenants")
            .select(tenantSelect)
            .eq("property_id", value: propertyId)
            .eq("active", value: true)
            .order("full_name")
            .execute()
            .value
    }

    func fetchTenant(id: UUID) async throws -> Tenant {
        try await client
            .from("tenants")
            .select(tenantSelect)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchAvailableTenants(propertyId: UUID) async throws -> [Tenant] {
        let allTenants = try await fetchTenants(propertyId: propertyId)
        return allTenants.filter { $0.active && !$0.isAssignedToRoom }
    }

    func createTenant(
        propertyId: UUID, fullName: String, email: String?, phone: String?, dni: String?,
        contractStartDate: Date?, contractMonths: Int?, contractEndDate: Date?,
        depositAmount: Decimal?, monthlyRent: Decimal?, currentAddress: String?,
        notes: String?, contractNotes: String?
    ) async throws -> Tenant {
        struct NewTenant: Encodable {
            let property_id: UUID
            let full_name: String
            let email: String?
            let phone: String?
            let dni: String?
            let contract_start_date: Date?
            let contract_months: Int?
            let contract_end_date: Date?
            let deposit_amount: Decimal?
            let monthly_rent: Decimal?
            let current_address: String?
            let notes: String?
            let contract_notes: String?
        }
        return
            try await client
            .from("tenants")
            .insert(
                NewTenant(
                    property_id: propertyId, full_name: fullName, email: email, phone: phone,
                    dni: dni, contract_start_date: contractStartDate,
                    contract_months: contractMonths,
                    contract_end_date: contractEndDate, deposit_amount: depositAmount,
                    monthly_rent: monthlyRent, current_address: currentAddress,
                    notes: notes, contract_notes: contractNotes
                )
            )
            .select(tenantSelect)
            .single()
            .execute()
            .value
    }

    func updateTenant(_ tenant: Tenant) async throws -> Tenant {
        struct UpdateTenant: Encodable {
            let full_name: String
            let email: String?
            let phone: String?
            let dni: String?
            let contract_start_date: Date?
            let contract_months: Int?
            let contract_end_date: Date?
            let deposit_amount: Decimal?
            let monthly_rent: Decimal?
            let current_address: String?
            let notes: String?
            let contract_notes: String?
            let active: Bool
        }
        return
            try await client
            .from("tenants")
            .update(
                UpdateTenant(
                    full_name: tenant.fullName, email: tenant.email, phone: tenant.phone,
                    dni: tenant.dni, contract_start_date: tenant.contractStartDate,
                    contract_months: tenant.contractMonths,
                    contract_end_date: tenant.contractEndDate,
                    deposit_amount: tenant.depositAmount, monthly_rent: tenant.monthlyRent,
                    current_address: tenant.currentAddress, notes: tenant.notes,
                    contract_notes: tenant.contractNotes, active: tenant.active
                )
            )
            .eq("id", value: tenant.id)
            .select(tenantSelect)
            .single()
            .execute()
            .value
    }

    func deactivateTenant(id: UUID) async throws {
        struct Deactivate: Encodable { let active = false }
        try await client
            .from("tenants")
            .update(Deactivate())
            .eq("id", value: id)
            .execute()
    }

    func assignToRoom(tenantId: UUID, roomId: UUID) async throws {
        let params = AssignTenantParams(p_tenant_id: tenantId, p_room_id: roomId)
        try await client.rpc("assign_tenant_to_room", params: params).execute()
    }

    func unassignFromRoom(roomId: UUID) async throws {
        let params = UnassignTenantParams(p_room_id: roomId)
        try await client.rpc("unassign_tenant_from_room", params: params).execute()
    }

    func renewContract(tenantId: UUID, contractMonths: Int) async throws {
        let tenant = try await fetchTenant(id: tenantId)
        guard let currentEndDate = tenant.contractEndDate else { return }

        let newStartDate = Calendar.current.date(byAdding: .day, value: 1, to: currentEndDate)!
        var newEndDate = Calendar.current.date(
            byAdding: .month, value: contractMonths, to: newStartDate)!
        let lastDay = Calendar.current.range(of: .day, in: .month, for: newEndDate)!.upperBound - 1
        newEndDate = Calendar.current.date(bySetting: .day, value: lastDay, of: newEndDate)!

        struct Renew: Encodable {
            let contract_start_date: Date
            let contract_end_date: Date
            let contract_months: Int
        }
        try await client
            .from("tenants")
            .update(
                Renew(
                    contract_start_date: newStartDate, contract_end_date: newEndDate,
                    contract_months: contractMonths)
            )
            .eq("id", value: tenantId)
            .execute()
    }

    func getExpiringContracts(daysAhead: Int = 30) async throws -> [Tenant] {
        let futureDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return
            try await client
            .from("tenants")
            .select(tenantSelect)
            .eq("active", value: true)
            .lte("contract_end_date", value: dateFormatter.string(from: futureDate))
            .gte("contract_end_date", value: dateFormatter.string(from: Date()))
            .order("contract_end_date")
            .execute()
            .value
    }
}
