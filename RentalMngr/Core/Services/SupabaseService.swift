import Auth
import Foundation
import Supabase

/// Session storage used ONLY on Mac Catalyst, where the Supabase SDK's default
/// KeychainLocalStorage fails: a Catalyst app without a keychain-access-group
/// entitlement gets `errSecMissingEntitlement (-34018)` on `SecItemAdd`. When
/// `store(...)` throws during sign-in, the SDK never persists the session, so
/// subsequent PostgREST requests go out WITHOUT the auth token — under RLS that
/// silently returns zero rows (the app looked logged in but read no data).
///
/// UserDefaults cannot fail on `store`, so the session persists and the token is
/// always attached. Trade-off: the session JWT lives unencrypted in the app
/// container's UserDefaults. Acceptable for the sandboxed Catalyst container
/// short-term. TODO: harden with a properly entitled data-protection keychain
/// item once the Catalyst keychain-access-group entitlement is configured.
/// iOS keeps the SDK's secure Keychain default (below).
private struct UserDefaultsAuthStorage: AuthLocalStorage {
    private let defaults = UserDefaults.standard
    private let prefix = "com.rentalmngr.auth."

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: prefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: prefix + key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: prefix + key)
    }
}

final class SupabaseService: Sendable {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        #if targetEnvironment(macCatalyst)
            let authStorage: any AuthLocalStorage = UserDefaultsAuthStorage()
        #else
            let authStorage: any AuthLocalStorage = AuthClient.Configuration.defaultLocalStorage
        #endif

        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                db: .init(
                    encoder: JSONEncoder.supabase,
                    decoder: JSONDecoder.supabase
                ),
                auth: .init(
                    storage: authStorage,
                    autoRefreshToken: true,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
