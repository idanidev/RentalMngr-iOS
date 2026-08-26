import Foundation

/// Enlaces legales que Apple exige mostrar en cualquier pantalla de suscripción
/// (Guideline 3.1.2). Sin ambos visibles, la app se rechaza.
enum LegalLinks {
    /// EULA estándar de Apple. Apple permite expresamente enlazarlo en lugar de
    /// redactar unos términos propios, y así no depende de que hospedemos nada.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Tienen que ser las MISMAS que se declaran en App Store Connect: un enlace
    /// roto aquí también es motivo de rechazo. Las anteriores apuntaban a un
    /// repo de GitHub Pages que nunca llegó a existir y devolvían 404.
    static let privacy = URL(string: "https://idanidev-portfolio.vercel.app/rentalmngr/privacidad.html")!

    static let support = URL(string: "https://idanidev-portfolio.vercel.app/rentalmngr/soporte.html")!
}
