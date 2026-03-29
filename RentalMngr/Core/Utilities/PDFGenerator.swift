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

    // MARK: - Contract PDF (Full Legal — matches web app contract.js)

    func generateContract(
        tenant: Tenant, room: Room, property: Property, landlord: LandlordProfile,
        template: String? = nil
    )
        async throws -> Data
    {
        // 1. Determine template source
        let templateBody: String

        if let customTemplate = template, !customTemplate.isEmpty {
            templateBody = customTemplate
        } else if let propertyTemplate = property.contractTemplate, !propertyTemplate.isEmpty {
            templateBody = propertyTemplate
        } else {
            // Fallback to global/default
            let templateService = ContractTemplateService()
            templateBody = try await templateService.getTemplate()
        }

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let contentWidth = pageWidth - margin * 2

        // Format helpers — use current locale for dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.locale = Locale.current

        func fmtDate(_ date: Date?) -> String {
            guard let d = date else { return "" }
            return dateFormatter.string(from: d)
        }

        let rent = Int(truncating: room.monthlyRent as NSDecimalNumber)
        let deposit = Int(truncating: (tenant.depositAmount ?? 0) as NSDecimalNumber)
        let depositWords = Self.numberToWords(deposit).uppercased()
        let tenantAddress = tenant.currentAddress ?? property.address

        let pdfData = await Task.detached(priority: .userInitiated) { [self] in
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            // MARK: — Agreement (Dynamic Template)

            // 1. Prepare replacements
            let currencySymbol = Locale.current.currencySymbol ?? "€"
            let replacements: [String: String] = [
                // Current format: {{snake_case}}
                "{{start_date}}": fmtDate(tenant.contractStartDate),
                "{{end_date}}": fmtDate(tenant.contractEndDate),
                "{{rent}}": "\(rent)\(currencySymbol)",
                "{{deposit}}": "\(deposit)\(currencySymbol)",
                "{{deposit_words}}": depositWords,
                "{{tenant_name}}": tenant.fullName,
                "{{tenant_dni}}": tenant.dni ?? "",
                "{{landlord_name}}": landlord.fullName,
                "{{landlord_dni}}": landlord.dni,
                "{{property_address}}": property.address,
                "{{tenant_address}}": tenantAddress,
                "{{date}}": dateFormatter.string(from: Date()),
                // Legacy format: {camelCase} (single braces, camelCase)
                "{startDateShort}": fmtDate(tenant.contractStartDate),
                "{endDateShort}": fmtDate(tenant.contractEndDate),
                "{monthlyRent}": "\(rent)\(currencySymbol)",
                "{depositAmount}": "\(deposit)\(currencySymbol)",
                "{depositAmountWords}": depositWords,
                "{tenantName}": tenant.fullName,
                "{tenantDni}": tenant.dni ?? "",
                "{landlordName}": landlord.fullName,
                "{landlordDni}": landlord.dni,
                "{propertyAddress}": property.address,
                "{tenantCurrentAddress}": tenantAddress,
                "{currentDate}": dateFormatter.string(from: Date()),
            ]

            // 2. Process replacements
            var bodyText = templateBody
            for (key, value) in replacements {
                bodyText = bodyText.replacingOccurrences(of: key, with: value)
            }

            // 3. Render paragraphs
            let lines = bodyText.components(separatedBy: "\n")

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // If distinct empty line, add spacing
                if trimmed.isEmpty {
                    y += 12
                    y = checkPageBreak(y: y, needed: 20, context: context)
                    continue
                }

                // Header check (### Header or ALL CAPS)
                var isHeader = false
                var displayText = trimmed

                if trimmed.hasPrefix("### ") {
                    isHeader = true
                    displayText = String(trimmed.dropFirst(4))
                } else if trimmed.count < 80 && trimmed == trimmed.uppercased() && trimmed.count > 3
                {
                    isHeader = true
                    displayText = trimmed
                }

                // Check page break
                y = checkPageBreak(y: y, needed: isHeader ? 50 : 20, context: context)

                if isHeader {
                    y =
                        drawColoredText(
                            displayText,
                            at: CGPoint(x: margin, y: y),
                            font: .boldSystemFont(ofSize: 14),  // Increased title size
                            color: charcoal,
                            maxWidth: contentWidth) + 8
                } else {
                    // Check for bold markers **text**
                    if displayText.contains("**") {
                        let spans = parseMarkdown(displayText)
                        y = drawMixedText(spans, at: y, contentWidth: contentWidth) + 4
                    } else {
                        y =
                            drawParagraph(
                                displayText,
                                at: y,
                                contentWidth: contentWidth) + 4
                    }
                }
            }

            y += 20

            // MARK: — Page 2: House Rules
            context.beginPage()
            y = margin

            y =
                drawColoredText(
                    String(localized: "RULES OF RESPECT AND GOOD COEXISTENCE",
                        locale: LanguageService.currentLocale, comment: "PDF house rules title"),
                    at: CGPoint(x: margin, y: y),
                    font: .boldSystemFont(ofSize: 14), color: navy, maxWidth: contentWidth) + 12

            let normas = [
                String(localized:
                        "Distribute and assign the different household tasks. This way, you will avoid arguments as much as possible. Leaving it to each person's goodwill does not work.",
                    locale: LanguageService.currentLocale, comment: "PDF house rule 1"),
                String(localized:
                        "Keep common rooms such as the bathroom or kitchen as clean and presentable as possible.",
                    locale: LanguageService.currentLocale, comment: "PDF house rule 2"),
                String(localized:
                        "Establish quiet hours as some housemates may need to work. Minimum quiet hours to respect: 11 PM to 8 AM. Do not use the washing machine, dishwasher, or any other noisy appliance after 11 PM.",
                    locale: LanguageService.currentLocale, comment: "PDF house rule 3"),
                String(localized:
                        "It is recommended not to display overly imposing or irritating attitudes, as you may end up losing housemates or not finding a flat.",
                    locale: LanguageService.currentLocale, comment: "PDF house rule 4"),
                String(localized:
                        "If anyone smokes, it must NEVER be done inside the house. Smoking should be done on the patio or terrace.",
                    locale: LanguageService.currentLocale, comment: "PDF house rule 5"),
                String(localized:
                        "A common fund is recommended for purchasing shared products such as dishwasher soap, toilet paper, laundry detergent, etc.",
                    locale: LanguageService.currentLocale, comment: "PDF house rule 6"),
                String(localized:
                        "Do not tamper with the water heater or pellet stove. Report any malfunctions.",
                    locale: LanguageService.currentLocale, comment: "PDF house rule 7"),
                String(localized:
                        "Refrigerator: Organize space according to the number of housemates. Clean the interior at least once a month.",
                    locale: LanguageService.currentLocale, comment: "PDF house rule 8"),
                String(localized:
                        "Do not accumulate trash inside the house. It is essential to take it out daily.",
                    locale: LanguageService.currentLocale, comment: "PDF house rule 9"),
            ]

            for norma in normas {
                y = checkPageBreak(y: y, needed: 40, context: context)
                y =
                    drawColoredText(
                        "• \(norma)", at: CGPoint(x: margin + 5, y: y),
                        font: .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth - 10)
                    + 6
            }

            // Contract notes if any
            if let notes = tenant.contractNotes, !notes.isEmpty {
                y += 10
                y = checkPageBreak(y: y, needed: 60, context: context)
                y =
                    drawColoredText(
                        String(localized: "SPECIAL CONDITIONS",
                            locale: LanguageService.currentLocale, comment: "PDF contract special conditions header"),
                        at: CGPoint(x: margin, y: y),
                        font: .boldSystemFont(ofSize: 12), color: navy, maxWidth: contentWidth) + 6
                y =
                    drawColoredText(
                        notes, at: CGPoint(x: margin, y: y),
                        font: .italicSystemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth
                    ) + 10
            }

            // Footer on both pages
            drawPremiumFooter(context: context)
            }
        }.value
        return pdfData
    }

    // MARK: - Markdown Parsing

    private func parseMarkdown(_ text: String) -> [TextSpan] {
        var spans: [TextSpan] = []
        let parts = text.components(separatedBy: "**")

        for (i, part) in parts.enumerated() {
            if part.isEmpty { continue }
            // Odd indices are between **...** so they are bold
            // (0 is regular, 1 is bold, 2 is regular...)
            if i % 2 == 1 {
                spans.append(.bold(part))
            } else {
                spans.append(.regular(part))
            }
        }
        return spans
    }

    // MARK: - Mixed bold/regular text helper

    private enum TextSpan {
        case regular(String)
        case bold(String)

        var text: String {
            switch self {
            case .regular(let t), .bold(let t): return t
            }
        }
        var isBold: Bool {
            if case .bold = self { return true }
            return false
        }
    }

    private func drawMixedText(_ spans: [TextSpan], at y: CGFloat, contentWidth: CGFloat) -> CGFloat
    {

        let font = UIFont.systemFont(ofSize: 11)
        let boldFont = UIFont.boldSystemFont(ofSize: 11)

        // Build NSMutableAttributedString with bold regions
        let attr = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3

        for span in spans {
            let f = span.isBold ? boldFont : font
            let part = NSAttributedString(
                string: span.text,
                attributes: [
                    .font: f,
                    .foregroundColor: charcoal,
                    .paragraphStyle: paragraphStyle,
                ])
            attr.append(part)
        }

        let boundingRect = attr.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil)

        let drawRect = CGRect(x: margin, y: y, width: contentWidth, height: boundingRect.height)
        attr.draw(in: drawRect)
        return y + boundingRect.height
    }

    /// Draw a plain paragraph at standard size
    private func drawParagraph(_ text: String, at y: CGFloat, contentWidth: CGFloat) -> CGFloat {
        drawColoredText(
            text, at: CGPoint(x: margin, y: y),
            font: .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth)
    }

    /// If remaining space is less than `needed`, start a new page
    private func checkPageBreak(y: CGFloat, needed: CGFloat, context: UIGraphicsPDFRendererContext)
        -> CGFloat
    {
        if y + needed > pageHeight - margin {
            context.beginPage()
            return margin
        }
        return y
    }

    // MARK: - Number to Words

    static func numberToWords(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    // MARK: - Room Ad PDF (Premium — matches webapp generateRoomAd)

    func generateRoomAd(
        room: Room, property: Property, commonRooms: [Room] = [],
        depositAmount: Decimal? = nil, ownerContact: String? = nil,
        roomImages: [UIImage] = [], commonRoomImages: [String: [UIImage]] = [:]
    ) async -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let contentWidth = pageWidth - margin * 2

        return await Task.detached(priority: .userInitiated) { [self] in
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 0

            // Header bar (navy)
            drawRect(
                at: CGRect(x: 0, y: 0, width: pageWidth, height: 90), color: navy, context: context)

            // Status badge
            let badgeText = String(localized: "FOR RENT", locale: LanguageService.currentLocale, comment: "PDF room ad status badge")
            let badgeWidth: CGFloat = 110
            let badgeRect = CGRect(x: margin, y: 15, width: badgeWidth, height: 24)
            drawRect(at: badgeRect, color: emerald, context: context, cornerRadius: 12)
            drawColoredText(
                badgeText, at: CGPoint(x: margin + 8, y: 19),
                font: .boldSystemFont(ofSize: 10), color: .white, maxWidth: badgeWidth - 16)

            // Price badge
            let perMonth = String(localized: "/mo", locale: LanguageService.currentLocale, comment: "Per month abbreviation for rent")
            let priceText = "\(room.monthlyRent.formatted(currencyCode: "EUR"))\(perMonth)"
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
            let rentLabel = String(localized: "Rent", locale: LanguageService.currentLocale, comment: "PDF room ad rent label")
            let depositLabel = String(localized: "Deposit", locale: LanguageService.currentLocale, comment: "PDF room ad deposit label")
            let availabilityLabel = String(localized: "Availability", locale: LanguageService.currentLocale, comment: "PDF room ad availability label")
            let immediateValue = String(localized: "Immediate", locale: LanguageService.currentLocale, comment: "PDF room ad immediate availability")
            drawInfoBox(
                title: rentLabel,
                value: "\(room.monthlyRent.formatted(currencyCode: "EUR"))\(perMonth)",
                at: CGRect(x: margin, y: y, width: boxWidth, height: 50), context: context)
            let deposit = depositAmount ?? room.monthlyRent
            drawInfoBox(
                title: depositLabel, value: deposit.formatted(currencyCode: "EUR"),
                at: CGRect(x: margin + boxWidth + 10, y: y, width: boxWidth, height: 50),
                context: context)
            drawInfoBox(
                title: availabilityLabel, value: immediateValue,
                at: CGRect(x: margin + (boxWidth + 10) * 2, y: y, width: boxWidth, height: 50),
                context: context)
            y += 70

            // Room details section
            let detailsTitle = String(localized: "DETAILS", locale: LanguageService.currentLocale, comment: "PDF room ad details section title")
            y = drawPremiumSectionTitle(detailsTitle, at: y)
            let typeLabel = String(localized: "Type:", locale: LanguageService.currentLocale, comment: "PDF room ad type label")
            let privateRoomValue = String(localized: "Private room", locale: LanguageService.currentLocale, comment: "PDF room type private")
            let commonAreaValue = String(localized: "Common area", locale: LanguageService.currentLocale, comment: "PDF room type common")
            y = drawLabelValue(
                typeLabel,
                value: room.roomType == .privateRoom ? privateRoomValue : commonAreaValue,
                at: y)
            if let size = room.sizeSqm {
                let sizeLabel = String(localized: "Size:", locale: LanguageService.currentLocale, comment: "PDF room ad size label")
                y = drawLabelValue(sizeLabel, value: "\(size) m²", at: y)
            }
            y += 10

            // Description
            if let notes = room.notes, !notes.isEmpty {
                let descTitle = String(localized: "DESCRIPTION", locale: LanguageService.currentLocale, comment: "PDF room ad description section title")
                y = drawPremiumSectionTitle(descTitle, at: y)
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
                let photosTitle = String(localized: "ROOM PHOTOS", locale: LanguageService.currentLocale, comment: "PDF room ad photos section title")
                y = drawPremiumSectionTitle(photosTitle, at: y)
                y = drawPhotoGrid(roomImages, at: y, contentWidth: contentWidth, context: context)
                y += 15
            }

            // Common areas section
            if !commonRooms.isEmpty {
                if y > pageHeight - 160 {
                    context.beginPage()
                    y = margin
                }
                let commonTitle = String(localized: "COMMON AREAS", locale: LanguageService.currentLocale, comment: "PDF room ad common areas section title")
                y = drawPremiumSectionTitle(commonTitle, at: y)
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
                let contactPrefix = String(localized: "Contact: ", locale: LanguageService.currentLocale, comment: "PDF room ad contact prefix")
                drawRect(
                    at: CGRect(x: margin, y: y, width: contentWidth, height: 40), color: lightGray,
                    context: context, cornerRadius: 8)
                drawColoredText(
                    "\(contactPrefix)\(contact)", at: CGPoint(x: margin + 12, y: y + 12),
                    font: .systemFont(ofSize: 12), color: charcoal, maxWidth: contentWidth - 24)
                y += 55
            }

            // Footer
            drawPremiumFooter(context: context)
            }
        }.value
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

        let pool = String(localized: "Pool", locale: LanguageService.currentLocale, comment: "PDF amenity pool")
        let garden = String(localized: "Garden", locale: LanguageService.currentLocale, comment: "PDF amenity garden")
        let terrace = String(localized: "Terrace", locale: LanguageService.currentLocale, comment: "PDF amenity terrace")
        let parking = String(localized: "Parking", locale: LanguageService.currentLocale, comment: "PDF amenity parking")
        let kitchen = String(localized: "Kitchen", locale: LanguageService.currentLocale, comment: "PDF amenity kitchen")
        let livingRoom = String(localized: "Living room", locale: LanguageService.currentLocale, comment: "PDF amenity living room")

        // Search both Spanish and English common room names
        if names.contains(where: { $0.contains("piscina") || $0.contains("pool") }) {
            amenities.append(pool)
        }
        if names.contains(where: {
            $0.contains("jardín") || $0.contains("jardin") || $0.contains("garden")
        }) {
            amenities.append(garden)
        }
        if names.contains(where: {
            $0.contains("terraza") || $0.contains("terrace") || $0.contains("balcony")
        }) {
            amenities.append(terrace)
        }
        if names.contains(where: {
            $0.contains("parking") || $0.contains("garaje") || $0.contains("garage")
        }) {
            amenities.append(parking)
        }
        if names.contains(where: { $0.contains("cocina") || $0.contains("kitchen") }) {
            amenities.append(kitchen)
        }
        if names.contains(where: {
            $0.contains("salón") || $0.contains("salon") || $0.contains("living")
        }) {
            amenities.append(livingRoom)
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
        dateFormatter.locale = Locale.current
        let dateStr = dateFormatter.string(from: Date())
        let footerText = String(localized: "Generated with Rental Manager", locale: LanguageService.currentLocale, comment: "PDF footer text")
        drawColoredText(
            "\(footerText) · \(dateStr)", at: CGPoint(x: margin, y: footerY),
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

}
