import Foundation
import Supabase

protocol RentChangeServiceProtocol: Sendable {
    /// Historial de un inquilino, lo más reciente primero.
    func fetchChanges(tenantId: UUID) async throws -> [RentChange]
    /// Registra una subida y la aplica: renta del inquilino, de su habitación y
    /// cobros pendientes desde la fecha en que rige.
    func recordChange(
        tenantId: UUID, newAmount: Decimal, effectiveDate: Date, note: String?
    ) async throws -> RentChange
}

// A nivel de fichero y `nonisolated`, como el resto de parámetros de RPC: dentro
// del método heredaría el aislamiento del actor principal y no sería Sendable.
nonisolated private struct RecordRentChangeParams: Encodable, Sendable {
    let p_tenant_id: UUID
    let p_new_amount: Decimal
    let p_effective_date: String
    let p_note: String?
}

final class RentChangeService: RentChangeServiceProtocol {
    private var client: SupabaseClient { SupabaseService.shared.client }

    func fetchChanges(tenantId: UUID) async throws -> [RentChange] {
        try await client
            .from(SupabaseTable.rentChanges)
            .select()
            .eq("tenant_id", value: tenantId)
            .order("effective_date", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Todo pasa en `record_rent_change`, en una sola transacción. Si se hiciera
    /// desde aquí en varias llamadas, un fallo a mitad dejaría el historial
    /// apuntado con la renta sin cambiar, o al revés.
    func recordChange(
        tenantId: UUID, newAmount: Decimal, effectiveDate: Date, note: String?
    ) async throws -> RentChange {
        return try await client
            .rpc(
                "record_rent_change",
                params: RecordRentChangeParams(
                    p_tenant_id: tenantId,
                    p_new_amount: newAmount,
                    p_effective_date: RentChange.dayFormatter.string(from: effectiveDate),
                    p_note: note))
            .execute()
            .value
    }
}
