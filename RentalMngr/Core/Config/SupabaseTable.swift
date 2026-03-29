import Foundation

/// Centralised Supabase table name constants — avoids scattered string literals.
enum SupabaseTable {
    static let properties = "properties"
    static let rooms = "rooms"
    static let tenants = "tenants"
    static let expenses = "expenses"
    static let income = "income"
    static let propertyAccess = "property_access"
    static let invitations = "invitations"
    static let notifications = "notifications"
    static let notificationSettings = "notification_settings"
    static let houseRules = "house_rules"
    static let sharedExpenses = "shared_expenses"
    static let reminders = "reminders"
    static let documents = "documents"
    static let inventoryItems = "inventory_items"
    static let propertyUtilities = "property_utilities"
    static let utilityCharges = "utility_charges"
    static let landlordProfiles = "landlord_profiles"
}
