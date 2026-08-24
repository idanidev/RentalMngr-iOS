import Foundation

/// Enlaces legales que Apple exige mostrar en cualquier pantalla de suscripción
/// (Guideline 3.1.2). Sin ambos visibles, la app se rechaza.
enum LegalLinks {
    /// EULA estándar de Apple. Apple permite expresamente enlazarlo en lugar de
    /// redactar unos términos propios, y así no depende de que hospedemos nada.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// ⚠️ SUSTITUIR por la URL real cuando se publique `privacy-policy.html`
    /// (ver HOSTING_INSTRUCCIONES.md). Debe ser la MISMA que se declare en
    /// App Store Connect. Un enlace roto aquí también es motivo de rechazo.
    static let privacy = URL(string: "https://idanidev.github.io/rentalmngr-privacy/")!

    static let support = URL(string: "https://idanidev.github.io/rentalmngr-privacy/support.html")!
}
