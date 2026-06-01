import Foundation

enum InputValidator {

    // MARK: - Strings

    static func requireString(_ value: String, field: String, maxLength: Int = 255) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.validation(String(localized: "\(field) es obligatorio", locale: LanguageService.currentLocale))
        }
        guard trimmed.count <= maxLength else {
            throw AppError.validation(String(localized: "\(field) no puede superar \(maxLength) caracteres", locale: LanguageService.currentLocale))
        }
        return trimmed
    }

    static func optionalString(_ value: String?, field: String, maxLength: Int = 500) throws -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return try requireString(value, field: field, maxLength: maxLength)
    }

    // MARK: - Email

    static func requireEmail(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count <= 254,
              trimmed.range(of: #"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"#, options: .regularExpression) != nil else {
            throw AppError.validation(String(localized: "Formato de email no válido", locale: LanguageService.currentLocale))
        }
        return trimmed
    }

    // MARK: - Numeric

    static func requireDecimal(_ value: Decimal, field: String, min: Decimal = 0, max: Decimal = 999_999) throws -> Decimal {
        guard value >= min, value <= max else {
            throw AppError.validation(String(localized: "\(field) fuera de rango", locale: LanguageService.currentLocale))
        }
        return value
    }

    // MARK: - Dates

    static func requireDateRange(start: Date, end: Date, maxYears: Int = 10) throws {
        guard start < end else {
            throw AppError.validation(String(localized: "La fecha de inicio debe ser anterior a la de fin", locale: LanguageService.currentLocale))
        }
        if let maxEnd = Calendar.current.date(byAdding: .year, value: maxYears, to: start) {
            guard end <= maxEnd else {
                throw AppError.validation(String(localized: "La duración no puede superar \(maxYears) años", locale: LanguageService.currentLocale))
            }
        }
    }

    // MARK: - Search (whitelist approach)

    static func sanitizeSearch(_ query: String, maxLength: Int = 100) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "áéíóúàèìòùäëïöüñçÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÑÇ-"))
        let filtered = String(query.unicodeScalars.filter { allowed.contains($0) })
        return String(filtered.prefix(maxLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - File validation (magic bytes)

    enum FileSignature: CaseIterable, Sendable {
        case pdf, jpeg, png, heic

        var magicBytes: [UInt8] {
            switch self {
            case .pdf:  [0x25, 0x50, 0x44, 0x46]
            case .jpeg: [0xFF, 0xD8, 0xFF]
            case .png:  [0x89, 0x50, 0x4E, 0x47]
            case .heic: [0x00, 0x00, 0x00] // ftyp container — checked with offset
            }
        }

        var mimeType: String {
            switch self {
            case .pdf:  "application/pdf"
            case .jpeg: "image/jpeg"
            case .png:  "image/png"
            case .heic: "image/heic"
            }
        }

        func matches(_ data: Data) -> Bool {
            guard data.count >= 12 else { return false }
            let bytes = Array(data.prefix(12))
            switch self {
            case .heic:
                // ftyp box at offset 4, then "heic" or "heix" or "mif1"
                let ftyp = bytes[4...7]
                guard ftyp.elementsEqual([0x66, 0x74, 0x79, 0x70]) else { return false }
                let brand = String(bytes: bytes[8...11], encoding: .ascii) ?? ""
                return ["heic", "heix", "mif1"].contains(brand)
            default:
                let magic = magicBytes
                return bytes.prefix(magic.count).elementsEqual(magic)
            }
        }
    }

    static func validateFile(
        data: Data,
        maxSizeMB: Int = 10,
        allowedTypes: [FileSignature] = FileSignature.allCases
    ) throws -> FileSignature {
        guard data.count <= maxSizeMB * 1_048_576 else {
            throw AppError.validation(String(localized: "El archivo supera el límite de \(maxSizeMB) MB", locale: LanguageService.currentLocale))
        }
        for type in allowedTypes {
            if type.matches(data) { return type }
        }
        throw AppError.validation(String(localized: "Tipo de archivo no permitido", locale: LanguageService.currentLocale))
    }
}
