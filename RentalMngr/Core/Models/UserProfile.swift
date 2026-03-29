import Foundation

struct LandlordProfile: Codable, Sendable {
    var fullName: String
    var dni: String
    var address: String
    var email: String
    var phone: String?

    static let empty = LandlordProfile(fullName: "", dni: "", address: "", email: "", phone: nil)

    /// Placeholder defaults — user should fill in their actual data
    static let `default` = LandlordProfile(
        fullName: "",
        dni: "",
        address: "",
        email: "",
        phone: nil
    )
}
