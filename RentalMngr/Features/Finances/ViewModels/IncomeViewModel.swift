import Foundation

@Observable
final class IncomeViewModel {
    var amount = ""
    var month = Date()
    var roomId: UUID?
    var isLoading = false
    var errorMessage: String?

    let propertyId: UUID
    private let financeService: FinanceService

    init(propertyId: UUID, financeService: FinanceService) {
        self.propertyId = propertyId
        self.financeService = financeService
    }

    var isFormValid: Bool {
        Decimal(string: amount) != nil && roomId != nil
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
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
