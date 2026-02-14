import PDFKit
import UIKit

final class PDFGenerator {
    private let pageWidth: CGFloat = 595.2  // A4
    private let pageHeight: CGFloat = 841.8
    private let margin: CGFloat = 40

    // MARK: - Premium Color Palette (matches webapp pdfService.js)
    private let navy = UIColor(red: 0.11, green: 0.15, blue: 0.27, alpha: 1)
    private let gold = UIColor(red: 0.84, green: 0.64, blue: 0.26, alpha: 1)
    private let emerald = UIColor(red: 0.04, green: 0.54, blue: 0.39, alpha: 1)
    private let charcoal = UIColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1)
    private let lightGray = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)

    // MARK: - Contract PDF (Premium)

    func generateContract(tenant: Tenant, room: Room, property: Property) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 0
            let contentWidth = pageWidth - margin * 2

            // Header bar (navy background)
            drawRect(
                at: CGRect(x: 0, y: 0, width: pageWidth, height: 80), color: navy, context: context)
            drawColoredText(
                "CONTRATO DE ARRENDAMIENTO", at: CGPoint(x: margin, y: 25),
                font: .boldSystemFont(ofSize: 22), color: .white, maxWidth: contentWidth,
                alignment: .center)

            // Gold accent line
            drawRect(
                at: CGRect(x: margin, y: 82, width: contentWidth, height: 3), color: gold,
                context: context)
            y = 100

            // PARTES section
            y = drawPremiumSectionTitle("PARTES", at: y)

            // Two-column party cards
            let cardWidth = (contentWidth - 20) / 2
            drawInfoCard(
                title: "ARRENDADOR", lines: [property.name, property.address],
                at: CGRect(x: margin, y: y, width: cardWidth, height: 60), context: context)

            var tenantLines = [tenant.fullName]
            if let dni = tenant.dni { tenantLines.append("DNI/NIE: \(dni)") }
            if let email = tenant.email { tenantLines.append(email) }
            drawInfoCard(
                title: "ARRENDATARIO", lines: tenantLines,
                at: CGRect(x: margin + cardWidth + 20, y: y, width: cardWidth, height: 60),
                context: context)
            y += 80

            // OBJETO section
            y = drawPremiumSectionTitle("OBJETO DEL CONTRATO", at: y)
            let roomDesc =
                "Habitación \"\(room.name)\" (\(room.roomType == .privateRoom ? "privada" : "común")) en la propiedad \"\(property.name)\", ubicada en \(property.address)."
            y =
                drawColoredText(
                    roomDesc, at: CGPoint(x: margin, y: y),
                    font: .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth) + 15

            // CONDICIONES ECONÓMICAS — 3 info boxes
            y = drawPremiumSectionTitle("CONDICIONES ECONÓMICAS", at: y)
            let boxWidth = (contentWidth - 20) / 3
            let durationText = tenant.contractMonths.map { "\($0) meses" } ?? "Indefinido"
            drawInfoBox(
                title: "Duración", value: durationText,
                at: CGRect(x: margin, y: y, width: boxWidth, height: 50), context: context)
            drawInfoBox(
                title: "Renta mensual", value: formatCurrency(room.monthlyRent),
                at: CGRect(x: margin + boxWidth + 10, y: y, width: boxWidth, height: 50),
                context: context)
            let depositText = tenant.depositAmount.map { formatCurrency($0) } ?? "N/A"
            drawInfoBox(
                title: "Fianza", value: depositText,
                at: CGRect(x: margin + (boxWidth + 10) * 2, y: y, width: boxWidth, height: 50),
                context: context)
            y += 70

            // Dates
            if let start = tenant.contractStartDate {
                y = drawLabelValue("Fecha de inicio:", value: start.dayMonthYear, at: y)
            }
            if let end = tenant.contractEndDate {
                y = drawLabelValue("Fecha de fin:", value: end.dayMonthYear, at: y)
            }
            y += 15

            // OBLIGACIONES
            y = drawPremiumSectionTitle("OBLIGACIONES", at: y)
            let obligations = [
                "El inquilino se compromete al pago mensual de la renta acordada antes del día 5 de cada mes.",
                "La fianza será devuelta al finalizar el contrato, previa revisión del estado del inmueble.",
                "Cualquier daño causado por el inquilino será responsabilidad del mismo.",
                "El inquilino se compromete a respetar las normas de convivencia establecidas.",
                "No se permitirán subarriendos sin autorización escrita del arrendador.",
                "El contrato puede ser renovado por acuerdo mutuo entre las partes.",
            ]
            for (i, obligation) in obligations.enumerated() {
                if y > pageHeight - 120 {
                    context.beginPage()
                    y = margin
                }
                y = drawBulletPoint("\(i + 1). \(obligation)", at: y, context: context)
            }
            y += 15

            // Contract notes if any
            if let notes = tenant.contractNotes, !notes.isEmpty {
                if y > pageHeight - 160 {
                    context.beginPage()
                    y = margin
                }
                y = drawPremiumSectionTitle("CONDICIONES PARTICULARES", at: y)
                y =
                    drawColoredText(
                        notes, at: CGPoint(x: margin, y: y),
                        font: .italicSystemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth
                    ) + 20
            }

            // Signatures — ensure on same page
            if y > pageHeight - 180 {
                context.beginPage()
                y = margin
            }
            y += 30
            let sigWidth = (contentWidth - 40) / 2

            drawColoredText(
                "EL ARRENDADOR", at: CGPoint(x: margin, y: y),
                font: .boldSystemFont(ofSize: 11), color: navy, maxWidth: sigWidth,
                alignment: .center)
            drawColoredText(
                "EL ARRENDATARIO", at: CGPoint(x: margin + sigWidth + 40, y: y),
                font: .boldSystemFont(ofSize: 11), color: navy, maxWidth: sigWidth,
                alignment: .center)
            y += 50

            let ctx = context.cgContext
            ctx.setStrokeColor(navy.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: margin + 10, y: y))
            ctx.addLine(to: CGPoint(x: margin + sigWidth - 10, y: y))
            ctx.move(to: CGPoint(x: margin + sigWidth + 50, y: y))
            ctx.addLine(to: CGPoint(x: pageWidth - margin - 10, y: y))
            ctx.strokePath()

            y += 20
            drawColoredText(
                "Fecha: ___/___/______", at: CGPoint(x: margin, y: y),
                font: .systemFont(ofSize: 10), color: .gray, maxWidth: sigWidth)
            drawColoredText(
                "Fecha: ___/___/______", at: CGPoint(x: margin + sigWidth + 40, y: y),
                font: .systemFont(ofSize: 10), color: .gray, maxWidth: sigWidth)

            // Footer
            drawPremiumFooter(context: context)
        }
    }

    // MARK: - Room Ad PDF (Premium — matches webapp generateRoomAd)

    func generateRoomAd(
        room: Room, property: Property, commonRooms: [Room] = [],
        depositAmount: Decimal? = nil, ownerContact: String? = nil,
        roomImages: [UIImage] = [], commonRoomImages: [String: [UIImage]] = [:]
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let contentWidth = pageWidth - margin * 2

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 0

            // Header bar (navy)
            drawRect(
                at: CGRect(x: 0, y: 0, width: pageWidth, height: 90), color: navy, context: context)

            // Status badge
            let badgeText = "EN ALQUILER"
            let badgeWidth: CGFloat = 110
            let badgeRect = CGRect(x: margin, y: 15, width: badgeWidth, height: 24)
            drawRect(at: badgeRect, color: emerald, context: context, cornerRadius: 12)
            drawColoredText(
                badgeText, at: CGPoint(x: margin + 8, y: 19),
                font: .boldSystemFont(ofSize: 10), color: .white, maxWidth: badgeWidth - 16)

            // Price badge
            let priceText = "\(formatCurrency(room.monthlyRent))/mes"
            let priceWidth: CGFloat = 120
            let priceRect = CGRect(
                x: pageWidth - margin - priceWidth, y: 15, width: priceWidth, height: 24)
            drawRect(at: priceRect, color: gold, context: context, cornerRadius: 12)
            drawColoredText(
                priceText, at: CGPoint(x: pageWidth - margin - priceWidth + 8, y: 19),
                font: .boldSystemFont(ofSize: 11), color: .white, maxWidth: priceWidth - 16)

            // Title in header
            drawColoredText(
                room.name, at: CGPoint(x: margin, y: 50),
                font: .boldSystemFont(ofSize: 22), color: .white, maxWidth: contentWidth)
            drawColoredText(
                "\(property.name) · \(property.address)", at: CGPoint(x: margin, y: 73),
                font: .systemFont(ofSize: 11), color: UIColor.white.withAlphaComponent(0.8),
                maxWidth: contentWidth)

            // Gold accent line
            drawRect(
                at: CGRect(x: margin, y: 92, width: contentWidth, height: 3), color: gold,
                context: context)
            y = 110

            // Quick features bar (amenities auto-detected from common rooms)
            let amenities = detectAmenities(commonRooms: commonRooms, room: room)
            if !amenities.isEmpty {
                y = drawAmenitiesBar(amenities, at: y, contentWidth: contentWidth, context: context)
                y += 15
            }

            // Financial info boxes (3-column)
            let boxWidth = (contentWidth - 20) / 3
            drawInfoBox(
                title: "Alquiler", value: "\(formatCurrency(room.monthlyRent))/mes",
                at: CGRect(x: margin, y: y, width: boxWidth, height: 50), context: context)
            let deposit = depositAmount ?? room.monthlyRent
            drawInfoBox(
                title: "Fianza", value: formatCurrency(deposit),
                at: CGRect(x: margin + boxWidth + 10, y: y, width: boxWidth, height: 50),
                context: context)
            drawInfoBox(
                title: "Disponibilidad", value: "Inmediata",
                at: CGRect(x: margin + (boxWidth + 10) * 2, y: y, width: boxWidth, height: 50),
                context: context)
            y += 70

            // Room details section
            y = drawPremiumSectionTitle("DETALLES", at: y)
            y = drawLabelValue(
                "Tipo:", value: room.roomType == .privateRoom ? "Habitación privada" : "Zona común",
                at: y)
            if let size = room.sizeSqm {
                y = drawLabelValue("Tamaño:", value: "\(size) m²", at: y)
            }
            y += 10

            // Description
            if let notes = room.notes, !notes.isEmpty {
                y = drawPremiumSectionTitle("DESCRIPCIÓN", at: y)
                let lines = notes.components(separatedBy: "\n").prefix(5).joined(separator: "\n")
                y =
                    drawColoredText(
                        lines, at: CGPoint(x: margin, y: y),
                        font: .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth) + 15
            }

            // Room photos section — actual embedded images
            if !roomImages.isEmpty {
                if y > pageHeight - 200 {
                    context.beginPage()
                    y = margin
                }
                y = drawPremiumSectionTitle("FOTOS DE LA HABITACIÓN", at: y)
                y = drawPhotoGrid(roomImages, at: y, contentWidth: contentWidth, context: context)
                y += 15
            }

            // Common areas section
            if !commonRooms.isEmpty {
                if y > pageHeight - 160 {
                    context.beginPage()
                    y = margin
                }
                y = drawPremiumSectionTitle("ZONAS COMUNES", at: y)
                for commonRoom in commonRooms {
                    y = drawBulletPoint("• \(commonRoom.name)", at: y, context: context)
                    // Show common room photos if available
                    if let photos = commonRoomImages[commonRoom.id.uuidString], !photos.isEmpty {
                        if y > pageHeight - 160 {
                            context.beginPage()
                            y = margin
                        }
                        y = drawPhotoGrid(
                            Array(photos.prefix(2)), at: y, contentWidth: contentWidth,
                            context: context)
                        y += 5
                    }
                }
                y += 10
            }

            // Contact info
            if let contact = ownerContact, !contact.isEmpty {
                if y > pageHeight - 80 {
                    context.beginPage()
                    y = margin
                }
                drawRect(
                    at: CGRect(x: margin, y: y, width: contentWidth, height: 40), color: lightGray,
                    context: context, cornerRadius: 8)
                drawColoredText(
                    "Contacto: \(contact)", at: CGPoint(x: margin + 12, y: y + 12),
                    font: .systemFont(ofSize: 12), color: charcoal, maxWidth: contentWidth - 24)
                y += 55
            }

            // Footer
            drawPremiumFooter(context: context)
        }
    }

    /// Draw a grid of photos (2 columns) with rounded corners and aspect-fill
    private func drawPhotoGrid(
        _ images: [UIImage], at startY: CGFloat, contentWidth: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let columns = 2
        let spacing: CGFloat = 8
        let imgWidth = (contentWidth - spacing) / CGFloat(columns)
        let imgHeight = imgWidth * 0.65
        var y = startY
        let maxPhotos = min(images.count, 6)

        for i in stride(from: 0, to: maxPhotos, by: columns) {
            if y + imgHeight > pageHeight - 60 {
                context.beginPage()
                y = margin
            }
            for col in 0..<columns where i + col < maxPhotos {
                let x = margin + CGFloat(col) * (imgWidth + spacing)
                let rect = CGRect(x: x, y: y, width: imgWidth, height: imgHeight)
                let image = images[i + col]

                // Compute aspect-fill rect (preserves aspect ratio, crops overflow)
                let imageAspect = image.size.width / image.size.height
                let rectAspect = imgWidth / imgHeight
                var drawRect: CGRect
                if imageAspect > rectAspect {
                    // Image is wider — fit height, crop width
                    let drawWidth = imgHeight * imageAspect
                    let drawX = x + (imgWidth - drawWidth) / 2
                    drawRect = CGRect(x: drawX, y: y, width: drawWidth, height: imgHeight)
                } else {
                    // Image is taller — fit width, crop height
                    let drawHeight = imgWidth / imageAspect
                    let drawY = y + (imgHeight - drawHeight) / 2
                    drawRect = CGRect(x: x, y: drawY, width: imgWidth, height: drawHeight)
                }

                // Clip to rounded rect and draw
                let ctx = context.cgContext
                ctx.saveGState()
                let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: 6)
                ctx.addPath(clipPath.cgPath)
                ctx.clip()
                image.draw(in: drawRect)
                ctx.restoreGState()

                // Border
                ctx.setStrokeColor(UIColor.lightGray.withAlphaComponent(0.3).cgColor)
                ctx.setLineWidth(0.5)
                ctx.addPath(clipPath.cgPath)
                ctx.strokePath()
            }
            y += imgHeight + spacing
        }
        return y
    }

    // MARK: - Premium Helpers

    private func drawPremiumSectionTitle(_ title: String, at y: CGFloat) -> CGFloat {
        let contentWidth = pageWidth - margin * 2
        let textY =
            drawColoredText(
                title, at: CGPoint(x: margin, y: y),
                font: .boldSystemFont(ofSize: 13), color: navy, maxWidth: contentWidth) + 2

        // Gold underline
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: textY))
        path.addLine(to: CGPoint(x: margin + 60, y: textY))
        gold.setStroke()
        path.lineWidth = 2
        path.stroke()

        return textY + 8
    }

    private func drawInfoCard(
        title: String, lines: [String], at rect: CGRect, context: UIGraphicsPDFRendererContext
    ) {
        drawRect(at: rect, color: lightGray, context: context, cornerRadius: 6)
        var y = rect.origin.y + 8
        drawColoredText(
            title, at: CGPoint(x: rect.origin.x + 10, y: y),
            font: .boldSystemFont(ofSize: 9), color: navy, maxWidth: rect.width - 20)
        y += 14
        for line in lines {
            y =
                drawColoredText(
                    line, at: CGPoint(x: rect.origin.x + 10, y: y),
                    font: .systemFont(ofSize: 10), color: charcoal, maxWidth: rect.width - 20) + 2
        }
    }

    private func drawInfoBox(
        title: String, value: String, at rect: CGRect, context: UIGraphicsPDFRendererContext
    ) {
        drawRect(at: rect, color: lightGray, context: context, cornerRadius: 6)
        drawColoredText(
            title, at: CGPoint(x: rect.origin.x + 8, y: rect.origin.y + 8),
            font: .systemFont(ofSize: 9), color: .gray, maxWidth: rect.width - 16)
        drawColoredText(
            value, at: CGPoint(x: rect.origin.x + 8, y: rect.origin.y + 24),
            font: .boldSystemFont(ofSize: 13), color: navy, maxWidth: rect.width - 16)
    }

    private func drawBulletPoint(
        _ text: String, at y: CGFloat, context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let contentWidth = pageWidth - margin * 2 - 10
        return drawColoredText(
            text, at: CGPoint(x: margin + 10, y: y),
            font: .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth) + 4
    }

    private func drawAmenitiesBar(
        _ amenities: [String], at y: CGFloat, contentWidth: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var x = margin
        let chipHeight: CGFloat = 22
        let spacing: CGFloat = 8
        var currentY = y

        for amenity in amenities {
            let textWidth =
                amenity.size(withAttributes: [.font: UIFont.systemFont(ofSize: 9)]).width + 16
            if x + textWidth > margin + contentWidth {
                x = margin
                currentY += chipHeight + 4
            }
            let chipRect = CGRect(x: x, y: currentY, width: textWidth, height: chipHeight)
            drawRect(
                at: chipRect, color: navy.withAlphaComponent(0.1), context: context,
                cornerRadius: 11)
            drawColoredText(
                amenity, at: CGPoint(x: x + 8, y: currentY + 5),
                font: .systemFont(ofSize: 9), color: navy, maxWidth: textWidth - 16)
            x += textWidth + spacing
        }
        return currentY + chipHeight
    }

    private func detectAmenities(commonRooms: [Room], room: Room) -> [String] {
        var amenities: [String] = []
        if let size = room.sizeSqm { amenities.append("\(size) m²") }
        let names = commonRooms.map { $0.name.lowercased() }
        if names.contains(where: { $0.contains("piscina") }) { amenities.append("Piscina") }
        if names.contains(where: { $0.contains("jardín") || $0.contains("jardin") }) {
            amenities.append("Jardín")
        }
        if names.contains(where: { $0.contains("terraza") }) { amenities.append("Terraza") }
        if names.contains(where: { $0.contains("parking") || $0.contains("garaje") }) {
            amenities.append("Parking")
        }
        if names.contains(where: { $0.contains("cocina") }) { amenities.append("Cocina") }
        if names.contains(where: { $0.contains("salón") || $0.contains("salon") }) {
            amenities.append("Salón")
        }
        if names.contains(where: { $0.contains("wifi") }) { amenities.append("WiFi") }
        return amenities
    }

    private func drawPremiumFooter(context: UIGraphicsPDFRendererContext) {
        let footerY = pageHeight - 35
        let contentWidth = pageWidth - margin * 2
        // Thin line
        let ctx = context.cgContext
        ctx.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: footerY - 5))
        ctx.addLine(to: CGPoint(x: pageWidth - margin, y: footerY - 5))
        ctx.strokePath()

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "es_ES")
        let dateStr = dateFormatter.string(from: Date())
        drawColoredText(
            "Generado con Rental Manager · \(dateStr)", at: CGPoint(x: margin, y: footerY),
            font: .italicSystemFont(ofSize: 8), color: .gray, maxWidth: contentWidth,
            alignment: .center)
    }

    // MARK: - Core Drawing

    @discardableResult
    private func drawText(
        _ text: String, at point: CGPoint, font: UIFont, maxWidth: CGFloat,
        alignment: NSTextAlignment = .left
    ) -> CGFloat {
        drawColoredText(
            text, at: point, font: font, color: .black, maxWidth: maxWidth, alignment: alignment)
    }

    @discardableResult
    private func drawColoredText(
        _ text: String, at point: CGPoint, font: UIFont, color: UIColor,
        maxWidth: CGFloat, alignment: NSTextAlignment = .left
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineSpacing = 3

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: color,
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        let drawRect = CGRect(x: point.x, y: point.y, width: maxWidth, height: boundingRect.height)
        attributedString.draw(in: drawRect)

        return point.y + boundingRect.height
    }

    private func drawRect(
        at rect: CGRect, color: UIColor, context: UIGraphicsPDFRendererContext,
        cornerRadius: CGFloat = 0
    ) {
        let ctx = context.cgContext
        ctx.setFillColor(color.cgColor)
        if cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        } else {
            ctx.fill(rect)
        }
    }

    private func drawSectionTitle(_ title: String, at yPosition: CGFloat) -> CGFloat {
        drawText(
            title, at: CGPoint(x: margin, y: yPosition),
            font: .boldSystemFont(ofSize: 14), maxWidth: pageWidth - margin * 2) + 8
    }

    private func drawLabelValue(_ label: String, value: String, at yPosition: CGFloat) -> CGFloat {
        let labelWidth: CGFloat = 130
        let contentWidth = pageWidth - margin * 2
        drawColoredText(
            label, at: CGPoint(x: margin, y: yPosition),
            font: .boldSystemFont(ofSize: 11), color: charcoal, maxWidth: labelWidth)
        return drawColoredText(
            value, at: CGPoint(x: margin + labelWidth, y: yPosition),
            font: .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth - labelWidth) + 4
    }

    private func drawDivider(at yPosition: CGFloat, context: UIGraphicsPDFRendererContext)
        -> CGFloat
    {
        let ctx = context.cgContext
        ctx.setStrokeColor(gold.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: margin, y: yPosition))
        ctx.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
        ctx.strokePath()
        return yPosition
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
