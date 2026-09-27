import CoreGraphics
import UIKit

/// Prepara una foto para incrustarla en un PDF.
///
/// Core Graphics trata las imágenes de dos maneras muy distintas, y de ahí venían
/// los anuncios de 24 MB:
///
/// - Un `UIImage` normal, con sus píxeles descomprimidos, lo **remuestrea** al
///   tamaño en que lo dibujas. Las fotos del anuncio van a 250 pt, así que salen
///   a unos 130 KB cada una y no hay problema.
/// - Un `CGImage` respaldado por datos JPEG —lo que devuelve `UIImage(data:)` al
///   descargar una foto— lo **deja pasar tal cual**: mete el JPEG original entero
///   en el documento, a resolución completa, mida lo que mida. Seis fotos de
///   móvil son así seis ficheros enteros dentro del PDF.
///
/// El anuncio caía en el segundo caso, así que llevaba dentro las fotos
/// originales de 4032 px. Medido con seis: 2045 KB pasando enteras contra 285 KB
/// pasando por aquí.
///
/// La solución no es evitar el paso directo, que es bueno, sino controlar **qué**
/// JPEG pasa: se reduce la foto y se vuelve a comprimir a un tamaño razonable,
/// y entonces lo que se cuela en el PDF ya es pequeño.
enum PDFImageEncoder {

    /// Devuelve la foto reducida y respaldada por un JPEG nuevo, del tamaño que
    /// aquí se decide en lugar del que traiga el original.
    ///
    /// - Parameters:
    ///   - maxPixel: lado mayor en píxeles. El anuncio dibuja las fotos a unos
    ///     250 pt, así que con 1400 sobra incluso para imprimir.
    ///   - quality: compresión JPEG. Por debajo de 0,5 se notan los bloques en
    ///     paredes y superficies lisas, que es justo lo que se fotografía aquí.
    ///
    /// Si algo falla devuelve la imagen reducida sin comprimir: un PDF grande es
    /// mejor que un PDF sin fotos.
    static func forEmbedding(
        _ image: UIImage, maxPixel: CGFloat = 1400, quality: CGFloat = 0.6
    ) -> UIImage {
        let scaled = downsample(image, maxPixel: maxPixel)
        guard let jpeg = scaled.jpegData(compressionQuality: quality),
            let provider = CGDataProvider(data: jpeg as CFData),
            let cgImage = CGImage(
                jpegDataProviderSource: provider, decode: nil,
                shouldInterpolate: true, intent: .defaultIntent)
        else {
            return scaled
        }
        // `jpegData` ya deja la orientación aplicada en los píxeles, así que la
        // imagen reconstruida va derecha y no hay que arrastrar la original.
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private static func downsample(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height) * image.scale
        guard longest > maxPixel, longest > 0 else { return image }

        let ratio = maxPixel / longest
        let target = CGSize(
            width: (image.size.width * image.scale * ratio).rounded(),
            height: (image.size.height * image.scale * ratio).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        // Las fotos de habitaciones no tienen transparencia, y opaco evita
        // arrastrar un canal alfa que el JPEG va a tirar igualmente.
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
