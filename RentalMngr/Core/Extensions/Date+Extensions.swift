import Foundation

extension String {
    /// RFC 5322-compatible email validation (local@domain.tld)
    var isValidEmail: Bool {
        let pattern = #"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}

extension Date {
    /// Locale-aware relative date (e.g. "2 days ago")
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Locale-aware month + year (e.g. "February 2026" / "Febrero 2026")
    var monthYear: String {
        formatted(.dateTime.month(.wide).year())
    }

    /// Locale-aware abbreviated date (e.g. "Feb 15, 2026" / "15 feb 2026")
    var shortFormatted: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    /// Locale-aware full date (e.g. "February 15, 2026" / "15 de febrero de 2026")
    var dayMonthYear: String {
        formatted(date: .long, time: .omitted)
    }

    /// Whether the date is within 30 days from now (day-granular, timezone-safe)
    var isExpiringSoon: Bool {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        let startSelf = cal.startOfDay(for: self)
        let daysUntilExpiry = cal.dateComponents([.day], from: startToday, to: startSelf).day ?? 0
        return daysUntilExpiry >= 0 && daysUntilExpiry <= 30
    }

    /// Whether the date is in the past (day-granular, timezone-safe)
    var isExpired: Bool {
        let cal = Calendar.current
        return cal.startOfDay(for: self) < cal.startOfDay(for: Date())
    }

    /// Number of days from now until this date
    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: self).day ?? 0
    }
}
