import Foundation

enum Formatters {
    /// DateFormatter for "yyyy-MM-dd" used in Supabase queries
    static let dbDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
