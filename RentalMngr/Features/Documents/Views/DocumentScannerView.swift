import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: (Data, String) -> Void  // (pdfData, suggestedName)

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (Data, String) -> Void
        let dismiss: DismissAction

        init(onScan: @escaping (Data, String) -> Void, dismiss: DismissAction) {
            self.onScan = onScan
            self.dismiss = dismiss
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let data = makePDF(from: scan)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let name = "Scan_\(formatter.string(from: Date())).pdf"
            onScan(data, name)
            dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            dismiss()
        }

        private func makePDF(from scan: VNDocumentCameraScan) -> Data {
            let a4 = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
            let renderer = UIGraphicsPDFRenderer(bounds: a4)
            return renderer.pdfData { ctx in
                for i in 0..<scan.pageCount {
                    ctx.beginPage()
                    let image = scan.imageOfPage(at: i)
                    // Scale image to fit A4 keeping aspect ratio
                    let imgSize = image.size
                    let scale = min(a4.width / imgSize.width, a4.height / imgSize.height)
                    let drawRect = CGRect(
                        x: (a4.width - imgSize.width * scale) / 2,
                        y: (a4.height - imgSize.height * scale) / 2,
                        width: imgSize.width * scale,
                        height: imgSize.height * scale
                    )
                    image.draw(in: drawRect)
                }
            }
        }
    }
}
