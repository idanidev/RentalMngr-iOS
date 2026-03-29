import Foundation

/// Unified Supabase date decoder — handles all date formats returned by Supabase
/// Eliminates the 3 different date parsing implementations scattered across services
extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // 1. ISO8601 with fractional seconds (e.g., "2026-01-15T10:30:00.000Z")
            let isoFractional = ISO8601DateFormatter()
            isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFractional.date(from: dateString) { return date }

            // 2. ISO8601 without fractional seconds (e.g., "2026-01-15T10:30:00Z")
            let isoStandard = ISO8601DateFormatter()
            isoStandard.formatOptions = [.withInternetDateTime]
            if let date = isoStandard.date(from: dateString) { return date }

            // 3. Date-only format (e.g., "2026-01-15")
            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"
            dateOnly.locale = Locale(identifier: "en_US_POSIX")
            if let date = dateOnly.date(from: dateString) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let supabase: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"
            dateOnly.locale = Locale(identifier: "en_US_POSIX")
            var container = encoder.singleValueContainer()
            try container.encode(dateOnly.string(from: date))
        }
        return encoder
    }()
}
