import Foundation
import SwiftUI

/// Expense categories — rawValue is the DB key (Spanish, stored in Supabase), displayName is localized
enum ExpenseCategory: String, CaseIterable, Identifiable {
    case maintenance = "Mantenimiento"
    case utilities = "Suministros"
    case insurance = "Seguros"
    case taxes = "Impuestos"
    case repairs = "Reparaciones"
    case cleaning = "Limpieza"
    case community = "Comunidad"
    case appliances = "Electrodomésticos"
    case other = "Otro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .maintenance:
            String(
                localized: "Maintenance", locale: LanguageService.currentLocale,
                comment: "Expense category")
        case .utilities:
            String(
                localized: "Utilities", locale: LanguageService.currentLocale,
                comment: "Expense category")
        case .insurance:
            String(
                localized: "Insurance", locale: LanguageService.currentLocale,
                comment: "Expense category")
        case .taxes:
            String(
                localized: "Taxes", locale: LanguageService.currentLocale,
                comment: "Expense category")
        case .repairs:
            String(
                localized: "Repairs", locale: LanguageService.currentLocale,
                comment: "Expense category")
        case .cleaning:
            String(
                localized: "Cleaning", locale: LanguageService.currentLocale,
                comment: "Expense category")
        case .community:
            String(
                localized: "Community", locale: LanguageService.currentLocale,
                comment: "Expense category")
        case .appliances:
            String(
                localized: "Appliances", locale: LanguageService.currentLocale,
                comment: "Expense category")
        case .other:
            String(
                localized: "Other", locale: LanguageService.currentLocale,
                comment: "Expense category")
        }
    }

    /// Attempt to map a raw string from DB to an Enum case robustly
    private static func mapRaw(_ raw: String) -> ExpenseCategory? {
        if let exact = ExpenseCategory(rawValue: raw) { return exact }
        switch raw.lowercased() {
        case "mantenimiento", "maintenance": return .maintenance
        case "suministros", "utilities", "agua", "luz", "gas", "calefaccion", "calefacción",
            "internet":
            return .utilities
        case "seguros", "insurance", "seguro": return .insurance
        case "impuestos", "taxes", "ibi", "tasa": return .taxes
        case "reparaciones", "repairs", "reparacion", "reparación": return .repairs
        case "limpieza", "cleaning": return .cleaning
        case "comunidad", "community", "community_fees", "gastos_comunidad": return .community
        case "electrodomésticos", "electrodomesticos", "appliances": return .appliances
        case "otro", "other", "otros": return .other
        default: return nil
        }
    }

    /// Display name for a raw DB category value
    static func displayName(for rawCategory: String) -> String {
        mapRaw(rawCategory)?.displayName ?? rawCategory
    }

    var icon: String {
        switch self {
        case .maintenance: "wrench.fill"
        case .utilities: "bolt.fill"
        case .insurance: "shield.fill"
        case .taxes: "doc.text.fill"
        case .repairs: "hammer.fill"
        case .cleaning: "sparkles"
        case .community: "building.2.fill"
        case .appliances: "washer.fill"
        case .other: "eurosign.circle"
        }
    }

    var color: Color {
        switch self {
        case .maintenance: .brown
        case .utilities: .yellow
        case .insurance: .green
        case .taxes: .red
        case .repairs: .orange
        case .cleaning: .mint
        case .community: .cyan
        case .appliances: .indigo
        case .other: .gray
        }
    }

    /// Icon for a raw DB category value
    static func icon(for rawCategory: String) -> String {
        mapRaw(rawCategory)?.icon ?? "eurosign.circle"
    }

    /// Color for a raw DB category value
    static func color(for rawCategory: String) -> Color {
        mapRaw(rawCategory)?.color ?? .gray
    }
}

@MainActor @Observable
final class ExpenseViewModel {
    var amount = ""
    var category = ExpenseCategory.maintenance.rawValue
    var description = ""
    var date = Date()
    var isLoading = false
    var errorMessage: String?

    let propertyId: UUID
    let isEditing: Bool
    private var expenseId: UUID?
    private var storedRoomId: UUID?  // ← preserve original room association on edit
    private let financeService: FinanceServiceProtocol
    private let userId: UUID

    init(
        propertyId: UUID, financeService: FinanceServiceProtocol, userId: UUID,
        expense: Expense? = nil
    ) {
        self.propertyId = propertyId
        self.financeService = financeService
        self.userId = userId
        if let expense {
            self.isEditing = true
            self.expenseId = expense.id
            self.storedRoomId = expense.roomId  // ← capture existing room
            self.amount = "\(expense.amount)"
            self.category = expense.category
            self.description = expense.description ?? ""
            self.date = expense.date
        } else {
            self.isEditing = false
        }
    }

    var isFormValid: Bool {
        guard let value = Decimal(string: amount) else { return false }
        return value > 0 && !category.isEmpty
    }

    func save() async -> Expense? {
        guard let decimalAmount = Decimal(string: amount) else { return nil }
        isLoading = true
        errorMessage = nil
        do {
            if isEditing, let expenseId {
                let expense = Expense(
                    id: expenseId, propertyId: propertyId, roomId: storedRoomId,
                    amount: decimalAmount, category: category,
                    description: description.isEmpty ? nil : description,
                    date: date, createdBy: userId, createdAt: nil, updatedAt: nil
                )
                let result = try await financeService.updateExpense(expense)
                isLoading = false
                return result
            } else {
                let result = try await financeService.createExpense(
                    propertyId: propertyId, amount: decimalAmount, category: category,
                    description: description.isEmpty ? nil : description,
                    date: date, roomId: nil, createdBy: userId
                )
                isLoading = false
                return result
            }
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
