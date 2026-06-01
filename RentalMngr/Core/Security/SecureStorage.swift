import Foundation
import CryptoKit

actor SecureStorage {

    static let shared = SecureStorage()

    private let keyIdentifier = "com.rentalmngr.secureStorage"
    private var cachedKey: SymmetricKey?

    // MARK: - Key management

    private func getOrCreateKey() throws -> SymmetricKey {
        if let cached = cachedKey { return cached }

        let tag = Data(keyIdentifier.utf8)

        // Try to load existing key from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let keyData = result as? Data {
            let key = SymmetricKey(data: keyData)
            cachedKey = key
            return key
        }

        // Generate and store new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AppError.unknown(NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus)))
        }

        cachedKey = newKey
        return newKey
    }

    // MARK: - Encrypt / Decrypt

    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw AppError.unknown(NSError(domain: "SecureStorage", code: -1))
        }
        return combined
    }

    func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Codable helpers

    func encryptCodable<T: Encodable>(_ value: T) throws -> Data {
        let jsonData = try JSONEncoder().encode(value)
        return try encrypt(jsonData)
    }

    func decryptCodable<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decryptedData = try decrypt(data)
        return try JSONDecoder().decode(type, from: decryptedData)
    }
}
