import Foundation

@MainActor @Observable
final class IncomeViewModel {
    var amount = ""
    var month = Date()
    var roomId: UUID?
    var isLoading = false
    var errorMessage: String?

    let propertyId: UUID
    private let financeService: FinanceServiceProtocol

    init(propertyId: UUID, financeService: FinanceServiceProtocol) {
        self.propertyId = propertyId
        self.financeService = financeService
    }

    var isFormValid: Bool {
        guard let value = Decimal(string: amount) else { return false }
        return value > 0 && roomId != nil
    }

    func save() async -> Income? {
        guard let decimalAmount = Decimal(string: amount), let roomId else { return nil }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await financeService.createIncome(
                propertyId: propertyId, roomId: roomId, amount: decimalAmount, month: month
            )
            isLoading = false
            return result
        } catch is CancellationError {
            // Tarea cancelada por navegación — no es un error real
            isLoading = false
            return nil
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
