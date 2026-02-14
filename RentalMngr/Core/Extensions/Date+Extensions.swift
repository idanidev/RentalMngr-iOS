import Foundation

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }

    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var dayMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: self)
    }

    var isExpiringSoon: Bool {
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: self).day ?? 0
        return daysUntilExpiry >= 0 && daysUntilExpiry <= 30
    }

    var isExpired: Bool {
        self < Date()
    }

    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: self).day ?? 0
    }
}
