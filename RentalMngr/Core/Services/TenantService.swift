import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "TenantService")

nonisolated private struct AssignTenantParams: Encodable, Sendable {
    let p_tenant_id: UUID
    let p_room_id: UUID
}

nonisolated private struct UnassignTenantParams: Encodable, Sendable {
    let p_room_id: UUID
}

final class TenantService: TenantServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    /// The join select string matching the webapp
    private let tenantSelect =
        "*, room:rooms!rooms_tenant_id_fkey(id, name, monthly_rent, size_sqm, room_type)"

    /// Fetch tenants WITH their assigned room info (joined)
    func fetchTenants(propertyId: UUID, limit: Int?, offset: Int?) async throws -> [Tenant] {
        var query =
            client
            .from(SupabaseTable.tenants)
            .select(tenantSelect)
            .eq("property_id", value: propertyId)
            .order("active", ascending: false)
            .order("full_name")

        if let limit, let offset {
            query = query.range(from: offset, to: offset + limit - 1)
        }

        let response = try await query.execute()

        logger.debug("Fetched tenant data: \(response.data.count) bytes")

        do {
            let tenants = try JSONDecoder.supabase.decode([Tenant].self, from: response.data)
            logger.debug("Successfully decoded \(tenants.count) tenants")
            return tenants
        } catch {
            logger.error("Decode error: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchActiveTenants(propertyId: UUID) async throws -> [Tenant] {
        try await client
            .from(SupabaseTable.tenants)
            .select(tenantSelect)
            .eq("property_id", value: propertyId)
            .eq("active", value: true)
            .order("full_name")
            .execute()
            .value
    }

    func fetchTenant(id: UUID) async throws -> Tenant {
        try await client
            .from(SupabaseTable.tenants)
            .select(tenantSelect)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchAvailableTenants(propertyId: UUID) async throws -> [Tenant] {
        let allTenants = try await fetchTenants(propertyId: propertyId, limit: nil, offset: nil)
        return allTenants.filter { $0.active && !$0.isAssignedToRoom }
    }

    func createTenant(_ params: CreateTenantParams) async throws -> Tenant {
        struct NewTenant: Encodable {
            let property_id: UUID
            let full_name: String
            let email: String?
            let phone: String?
            let dni: String?
            let contract_start_date: String?
            let contract_months: Int?
            let contract_end_date: String?
            let deposit_amount: Decimal?
            let monthly_rent: Decimal?
            let current_address: String?
            let notes: String?
            let contract_notes: String?
        }
        return
            try await client
            .from(SupabaseTable.tenants)
            .insert(
                NewTenant(
                    property_id: params.propertyId, full_name: params.fullName, email: params.email,
                    phone: params.phone,
                    dni: params.dni,
                    contract_start_date: params.contractStartDate.map { Formatters.dbDate.string(from: $0) },
                    contract_months: params.contractMonths,
                    contract_end_date: params.contractEndDate.map { Formatters.dbDate.string(from: $0) },
                    deposit_amount: params.depositAmount,
                    monthly_rent: params.monthlyRent, current_address: params.currentAddress,
                    notes: params.notes, contract_notes: params.contractNotes
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
            let contract_start_date: String?
            let contract_months: Int?
            let contract_end_date: String?
            let deposit_amount: Decimal?
            let monthly_rent: Decimal?
            let current_address: String?
            let notes: String?
            let contract_notes: String?
            let active: Bool
        }
        do {
            let updatePayload = UpdateTenant(
                full_name: tenant.fullName, email: tenant.email, phone: tenant.phone,
                dni: tenant.dni,
                contract_start_date: tenant.contractStartDate.map { Formatters.dbDate.string(from: $0) },
                contract_months: tenant.contractMonths,
                contract_end_date: tenant.contractEndDate.map { Formatters.dbDate.string(from: $0) },
                deposit_amount: tenant.depositAmount, monthly_rent: tenant.monthlyRent,
                current_address: tenant.currentAddress, notes: tenant.notes,
                contract_notes: tenant.contractNotes, active: tenant.active
            )

            if let data = try? JSONEncoder.supabase.encode(updatePayload) {
                logger.debug(
                    "UPDATE PAYLOAD: \(String(data: data, encoding: .utf8) ?? "unable to read")")
            }

            let response =
                try await client
                .from(SupabaseTable.tenants)
                .update(updatePayload)
                .eq("id", value: tenant.id)
                .select(tenantSelect)
                .single()
                .execute()

            do {
                return try JSONDecoder.supabase.decode(Tenant.self, from: response.data)
            } catch {
                logger.error("Failed to decode tenant after update: \(error)")
                throw error
            }
        } catch {
            logger.error("Update tenant failed: \(error)")
            throw error
        }
    }

    func deactivateTenant(id: UUID) async throws {
        struct Deactivate: Encodable { let active = false }
        try await client
            .from(SupabaseTable.tenants)
            .update(Deactivate())
            .eq("id", value: id)
            .execute()
    }

    func activateTenant(id: UUID) async throws {
        struct Activate: Encodable { let active = true }
        try await client
            .from(SupabaseTable.tenants)
            .update(Activate())
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

    func renewContract(tenantId: UUID, contractMonths: Int, currentEndDate: Date?) async throws {
        let safeMonths = (1...120).contains(contractMonths) ? contractMonths : 6
        let base = currentEndDate ?? Date()

        let calendar = Calendar.current
        guard let newStartDate = calendar.date(byAdding: .day, value: 1, to: base) else {
            throw NSError(
                domain: "TenantService", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(
                        localized: "No se pudieron calcular las nuevas fechas del contrato.",
                        locale: LanguageService.currentLocale,
                        comment: "Error when contract renewal date calculation fails")
                ])
        }

        guard let tentativeEnd = calendar.date(byAdding: .month, value: safeMonths, to: newStartDate) else {
            throw NSError(
                domain: "TenantService", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(
                        localized: "No se pudieron calcular las nuevas fechas del contrato.",
                        locale: LanguageService.currentLocale,
                        comment: "Error when contract renewal date calculation fails")
                ])
        }

        // Use day=0 of next month to get last day of tentativeEnd's month — reliable cross-platform
        var endComponents = calendar.dateComponents([.year, .month], from: tentativeEnd)
        endComponents.month = (endComponents.month ?? 1) + 1
        endComponents.day = 0

        guard let newEndDate = calendar.date(from: endComponents) else {
            throw NSError(
                domain: "TenantService", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(
                        localized: "No se pudieron calcular las nuevas fechas del contrato.",
                        locale: LanguageService.currentLocale,
                        comment: "Error when contract renewal date calculation fails")
                ])
        }

        struct Renew: Encodable {
            let contract_start_date: String
            let contract_end_date: String
            let contract_months: Int
        }
        let payload = Renew(
            contract_start_date: Formatters.dbDate.string(from: newStartDate),
            contract_end_date: Formatters.dbDate.string(from: newEndDate),
            contract_months: safeMonths)
try await client
            .from(SupabaseTable.tenants)
            .update(payload)
            .eq("id", value: tenantId)
            .execute()
    }

    func getExpiringContracts(daysAhead: Int = 30) async throws -> [Tenant] {
        let futureDate =
            Calendar.current.date(byAdding: .day, value: daysAhead, to: Date())
            ?? Date().addingTimeInterval(Double(daysAhead) * 86400)

        return
            try await client
            .from(SupabaseTable.tenants)
            .select(tenantSelect)
            .eq("active", value: true)
            .lte("contract_end_date", value: Formatters.dbDate.string(from: futureDate))
            .gte("contract_end_date", value: Formatters.dbDate.string(from: Date()))
            .order("contract_end_date")
            .execute()
            .value
    }

    func moveTenant(tenant: Tenant, toRoomId: UUID) async throws -> Tenant {
        // If already in a room, unassign it
        if let currentRoom = tenant.room {
            // Optimization: if same room, do nothing
            if currentRoom.id == toRoomId { return tenant }
            try await unassignFromRoom(roomId: currentRoom.id)
        }

        // Check if destination room is occupied?
        // For now, assuming UI handles this or API throws error if unique constraint violated.
        try await assignToRoom(tenantId: tenant.id, roomId: toRoomId)

        // Return refreshed tenant
        return try await fetchTenant(id: tenant.id)
    }
}
