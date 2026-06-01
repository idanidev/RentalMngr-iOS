import LocalAuthentication

actor BiometricAuth {

    enum BiometricError: LocalizedError {
        case notAvailable
        case notEnrolled
        case failed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                String(localized: "Biometría no disponible en este dispositivo", locale: LanguageService.currentLocale)
            case .notEnrolled:
                String(localized: "No hay biometría configurada. Actívala en Ajustes.", locale: LanguageService.currentLocale)
            case .failed(let msg): msg
            case .cancelled:
                String(localized: "Autenticación cancelada", locale: LanguageService.currentLocale)
            }
        }
    }

    nonisolated var isBiometricAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    nonisolated var biometryTypeName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometría"
        }
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancelar", locale: LanguageService.currentLocale)
        context.localizedFallbackTitle = String(localized: "Usar código", locale: LanguageService.currentLocale)

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error, error.code == LAError.biometryNotEnrolled.rawValue {
                throw BiometricError.notEnrolled
            }
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            guard success else {
                throw BiometricError.failed(
                    String(localized: "Autenticación biométrica fallida", locale: LanguageService.currentLocale)
                )
            }
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            case .userFallback:
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason
                )
                guard success else {
                    throw BiometricError.failed(
                        String(localized: "Autenticación fallida", locale: LanguageService.currentLocale)
                    )
                }
            default:
                throw BiometricError.failed(error.localizedDescription)
            }
        }
    }
}
