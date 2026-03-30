import Testing
import Foundation
@testable import RentalMngr

@Suite("Date extensions")
struct DateExtensionTests {

    // MARK: - isExpired

    @Test("isExpired is true for yesterday")
    func isExpiredYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(yesterday.isExpired == true)
    }

    @Test("isExpired is false for today")
    func isExpiredToday() {
        // "today" starts at midnight, so today's date should not be expired
        let today = Calendar.current.startOfDay(for: Date())
        #expect(today.isExpired == false)
    }

    @Test("isExpired is false for tomorrow")
    func isExpiredTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(tomorrow.isExpired == false)
    }

    @Test("isExpired is true for a date one year in the past")
    func isExpiredPastYear() {
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        #expect(lastYear.isExpired == true)
    }

    // MARK: - isExpiringSoon

    @Test("isExpiringSoon is true for today")
    func isExpiringSoonToday() {
        let today = Date()
        #expect(today.isExpiringSoon == true)
    }

    @Test("isExpiringSoon is true for a date 30 days from now")
    func isExpiringSoonExactly30Days() {
        let thirtyDays = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        #expect(thirtyDays.isExpiringSoon == true)
    }

    @Test("isExpiringSoon is false for a date 31 days from now")
    func isExpiringSoonBeyond30Days() {
        let thirtyOneDays = Calendar.current.date(byAdding: .day, value: 31, to: Date())!
        #expect(thirtyOneDays.isExpiringSoon == false)
    }

    @Test("isExpiringSoon is false for yesterday (already expired)")
    func isExpiringSoonExpiredDate() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(yesterday.isExpiringSoon == false)
    }

    // MARK: - daysUntil

    @Test("daysUntil is positive for a future date")
    func daysUntilFuture() {
        let future = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let days = future.daysUntil
        // Allow ±1 due to intra-day floating; the important thing is it's around 10
        #expect(days >= 9 && days <= 10)
    }

    @Test("daysUntil is negative for a past date")
    func daysUntilPast() {
        let past = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        #expect(past.daysUntil < 0)
    }
}

// MARK: - String extension tests

@Suite("String extensions")
struct StringExtensionTests {

    @Test("isValidEmail returns true for valid email")
    func validEmail() {
        #expect("user@example.com".isValidEmail == true)
    }

    @Test("isValidEmail returns true for email with subdomain")
    func validEmailSubdomain() {
        #expect("user@mail.example.co.uk".isValidEmail == true)
    }

    @Test("isValidEmail returns true for email with plus alias")
    func validEmailPlus() {
        #expect("user+alias@example.com".isValidEmail == true)
    }

    @Test("isValidEmail returns false for missing @")
    func invalidEmailNoAt() {
        #expect("userexample.com".isValidEmail == false)
    }

    @Test("isValidEmail returns false for missing domain")
    func invalidEmailNoDomain() {
        #expect("user@".isValidEmail == false)
    }

    @Test("isValidEmail returns false for missing TLD")
    func invalidEmailNoTLD() {
        #expect("user@example".isValidEmail == false)
    }

    @Test("isValidEmail returns false for empty string")
    func invalidEmailEmpty() {
        #expect("".isValidEmail == false)
    }
}
