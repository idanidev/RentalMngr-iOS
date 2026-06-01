import Foundation
import SwiftUI

@MainActor @Observable
final class AppLockManager {

    var isLocked = false
    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometricLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometricLockEnabled") }
    }

    private var backgroundDate: Date?
    private let lockTimeout: TimeInterval = 30
    private let biometricAuth = BiometricAuth()

    var isBiometricAvailable: Bool {
        biometricAuth.isBiometricAvailable
    }

    var biometryTypeName: String {
        biometricAuth.biometryTypeName
    }

    // MARK: - Scene phase handling

    func sceneDidEnterBackground() {
        guard isBiometricEnabled else { return }
        backgroundDate = Date()
    }

    func sceneWillEnterForeground() {
        guard isBiometricEnabled, let date = backgroundDate else { return }
        if Date().timeIntervalSince(date) > lockTimeout {
            isLocked = true
        }
        backgroundDate = nil
    }

    func lockIfEnabled() {
        if isBiometricEnabled {
            isLocked = true
        }
    }

    // MARK: - Unlock

    func unlock() async {
        do {
            try await biometricAuth.authenticate(
                reason: String(localized: "Desbloquea para acceder a RentalMngr", locale: LanguageService.currentLocale)
            )
            isLocked = false
        } catch {
            // Stay locked on failure/cancel
        }
    }

    /// Toggle biometric lock — authenticates before enabling
    func toggleBiometric() async -> Bool {
        if isBiometricEnabled {
            isBiometricEnabled = false
            isLocked = false
            return true
        } else {
            do {
                try await biometricAuth.authenticate(
                    reason: String(localized: "Confirma tu identidad para activar el bloqueo biométrico", locale: LanguageService.currentLocale)
                )
                isBiometricEnabled = true
                return true
            } catch {
                return false
            }
        }
    }
}
