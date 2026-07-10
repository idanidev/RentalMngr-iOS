import UIKit
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "PushManager")

/// Coordinates remote (APNs) push registration: asks iOS for a token, caches it,
/// and syncs it to Supabase for the signed-in user.
///
/// `shared` bridges the `UIApplicationDelegate` (created outside the SwiftUI
/// environment) back to this instance owned by `AppState`.
@MainActor
final class PushManager {
    static weak var shared: PushManager?

    private let deviceTokenService: DeviceTokenServiceProtocol
    private let authService: AuthService
    private let tokenDefaultsKey = "apnsDeviceToken"

    init(deviceTokenService: DeviceTokenServiceProtocol, authService: AuthService) {
        self.deviceTokenService = deviceTokenService
        self.authService = authService
    }

    var platform: String {
        #if targetEnvironment(macCatalyst)
        return "maccatalyst"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipados" : "ios"
        #endif
    }

    /// Ask iOS for an APNs token. Safe to call repeatedly; only succeeds once the
    /// Push Notifications capability is enabled (otherwise `didFailToRegister` fires).
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Called by `AppDelegate` when APNs returns a fresh token.
    func handleDeviceToken(_ token: String) async {
        UserDefaults.standard.set(token, forKey: tokenDefaultsKey)
        await uploadStoredToken()
    }

    /// Re-upload the cached token for the current user (e.g. after login or foreground).
    func syncCurrentUser() async {
        await uploadStoredToken()
    }

    /// Remove this device's token from the backend on sign-out.
    func clearOnSignOut() async {
        guard let token = UserDefaults.standard.string(forKey: tokenDefaultsKey) else { return }
        try? await deviceTokenService.deleteToken(token)
    }

    private func uploadStoredToken() async {
        guard
            let token = UserDefaults.standard.string(forKey: tokenDefaultsKey),
            let userId = authService.currentUserId
        else { return }
        do {
            try await deviceTokenService.upsertToken(userId: userId, token: token, platform: platform)
            logger.info("Device token synced for current user")
        } catch {
            logger.error("Failed to upsert device token: \(error.localizedDescription)")
        }
    }
}
