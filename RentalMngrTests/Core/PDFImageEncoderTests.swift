import Foundation
import Testing
import UIKit

@testable import RentalMngr

/// Cuánto ocupa un PDF con fotos dentro.
///
/// El anuncio de una habitación llegó a pesar 24 MB. La causa: una foto
/// descargada con `UIImage(data:)` queda respaldada por su JPEG original, y Core
/// Graphics mete ese JPEG entero en el PDF, a 4032 px, sin remuestrear. El test
/// que lo fija es `originalJPEGDoesNotPassThrough`; los demás cubren el resto del
/// comportamiento del codificador.
@MainActor
struct PDFImageEncoderTests {

    /// Una foto sintética que se parece a una de verdad: fondo plano más manchas,
    /// para que no se comprima sospechosamente bien.
    private func photo(side: CGFloat = 1400, seed semilla: UInt64 = 20_260_924) -> UIImage {
        let size = CGSize(width: side, height: side * 0.75)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(red: 0.85, green: 0.82, blue: 0.75, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Generador determinista: el mismo ruido en cada ejecución, para que
            // el tamaño medido no baile entre pasadas.
            var seed = semilla
            func next() -> CGFloat {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max)
            }
            for _ in 0..<1200 {
                UIColor(red: next(), green: next(), blue: next(), alpha: 0.35).setFill()
                ctx.fill(
                    CGRect(
                        x: next() * size.width, y: next() * size.height,
                        width: next() * 40 + 4, height: next() * 40 + 4))
            }
        }
    }

    /// Mete las fotos en un PDF como hace el anuncio: varias en una página.
    private func pdf(with images: [UIImage]) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40
            for image in images {
                image.draw(in: CGRect(x: 40, y: y, width: 250, height: 162))
                y += 170
            }
        }
    }

    private func kb(_ bytes: Int) -> String { String(format: "%.0f KB", Double(bytes) / 1024) }

    @Test("El anuncio con seis fotos adelgaza")
    func adGetsSmaller() {
        // Seis fotos DISTINTAS. Repetir la misma no mide nada: Core Graphics
        // incrusta un solo objeto y lo referencia seis veces, así que el PDF
        // salía pequeño aunque la foto fuera en crudo.
        let seis = (0..<6).map { photo(seed: 20_260_924 &+ UInt64($0) &* 7919) }

        let crudo = pdf(with: seis).count
        let comprimido = pdf(with: seis.map { PDFImageEncoder.forEmbedding($0) }).count
        print("Anuncio, 6 fotos — tal cual: \(kb(crudo)) · JPEG: \(kb(comprimido))")

        // El umbral sale de la medida, no de un deseo: con ruido sintético —que
        // es el peor caso para JPEG— queda en torno a 794 KB contra 404 KB. Con
        // fotos de verdad, que son suaves, la diferencia es mayor.
        #expect(comprimido < crudo * 3 / 4)
    }

    @Test("Un documento escaneado a página completa también adelgaza")
    func scannedPageGetsSmaller() {
        // Lo que entrega VNDocumentCameraScan: una foto de móvil a página entera.
        // Aquí la ganancia es menor que en el anuncio, porque el renderer ya
        // remuestrea un bitmap al tamaño de la página; se comprime igual para
        // que todos los PDF de la app sigan la misma regla.
        let a4 = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let paginas = (0..<3).map { photo(side: 3024, seed: 7_777 &+ UInt64($0) &* 104_729) }

        func documento(_ images: [UIImage]) -> Data {
            UIGraphicsPDFRenderer(bounds: a4).pdfData { ctx in
                for image in images {
                    ctx.beginPage()
                    image.draw(in: a4)
                }
            }
        }

        let crudo = documento(paginas).count
        let comprimido = documento(
            paginas.map { PDFImageEncoder.forEmbedding($0, maxPixel: 2200, quality: 0.7) }
        ).count
        print("Escaneo, 3 páginas — tal cual: \(kb(crudo)) · JPEG: \(kb(comprimido))")

        #expect(comprimido < crudo * 3 / 4)
        // Tres páginas escaneadas tienen que poder mandarse por correo.
        #expect(comprimido < 3 * 1024 * 1024)
    }

    @Test("Una foto descargada no puede colarse entera en el PDF")
    func originalJPEGDoesNotPassThrough() throws {
        // Esta era la causa de los anuncios de 24 MB. `UIImage(data:)` —lo que
        // sale de descargar una foto— queda respaldado por los bytes JPEG
        // originales, y Core Graphics los mete en el PDF tal cual, a 4032 px,
        // sin remuestrear nada: seis fotos de móvil son seis ficheros enteros.
        let seis = try (0..<6).map { i -> UIImage in
            let jpeg = try #require(
                photo(side: 4032, seed: 31_337 &+ UInt64(i) &* 7919)
                    .jpegData(compressionQuality: 0.9))
            return try #require(UIImage(data: jpeg))
        }

        let enteras = pdf(with: seis).count
        let reducidas = pdf(with: seis.map { PDFImageEncoder.forEmbedding($0) }).count
        print("6 fotos de 4032px — pasando enteras: \(kb(enteras)) · reducidas: \(kb(reducidas))")

        #expect(reducidas < enteras / 4)
    }


    @Test("La foto se reduce al lado mayor pedido y conserva la proporción")
    func downsamples() {
        let encoded = PDFImageEncoder.forEmbedding(photo(side: 4032), maxPixel: 1400)

        #expect(max(encoded.size.width, encoded.size.height) == 1400)
        // 4032 x 3024 es 4:3; tiene que seguir siéndolo.
        let aspecto = encoded.size.width / encoded.size.height
        #expect(abs(aspecto - 4.0 / 3.0) < 0.01)
    }

    @Test("Una foto ya pequeña no se agranda")
    func doesNotUpscale() {
        let encoded = PDFImageEncoder.forEmbedding(photo(side: 600), maxPixel: 1400)
        #expect(max(encoded.size.width, encoded.size.height) == 600)
    }

    @Test("Más calidad pesa más, que es lo que se espera al subirla")
    func qualityMatters() {
        let original = photo()
        let baja = pdf(with: [PDFImageEncoder.forEmbedding(original, quality: 0.3)]).count
        let alta = pdf(with: [PDFImageEncoder.forEmbedding(original, quality: 0.9)]).count
        #expect(alta > baja)
    }
}
