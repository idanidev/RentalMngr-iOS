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
        template: String? = nil, customVariables: [ContractVariable] = [],
        communityFeesIncludes: [String] = [], communityFeesAmount: Decimal? = nil
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
            let communityFeesInt = Int(truncating: (communityFeesAmount ?? 0) as NSDecimalNumber)
            let totalMonthlyInt = rent + communityFeesInt
            let replacements: [String: String] = [
                // Current format: {{snake_case}}
                "{{start_date}}": fmtDate(tenant.contractStartDate),
                "{{end_date}}": fmtDate(tenant.contractEndDate),
                "{{rent}}": rent > 0 ? "\(rent)\(currencySymbol)" : "",
                "{{deposit}}": deposit > 0 ? "\(deposit)\(currencySymbol)" : "",
                "{{deposit_words}}": deposit > 0 ? depositWords : "",
                "{{tenant_name}}": tenant.fullName,
                "{{tenant_dni}}": tenant.dni ?? "",
                "{{landlord_name}}": landlord.fullName,
                "{{landlord_dni}}": landlord.dni,
                "{{property_address}}": property.address,
                "{{room_name}}": room.name,
                "{{habitacion}}": room.name,
                "{{tenant_address}}": tenantAddress,
                "{{date}}": dateFormatter.string(from: Date()),
                "{{community_fees_includes}}": communityFeesIncludes.joined(separator: ", "),
                "{{gastos_comunes}}": communityFeesInt > 0 ? "\(communityFeesInt)\(currencySymbol)" : "",
                "{{community_fees}}": communityFeesInt > 0 ? "\(communityFeesInt)\(currencySymbol)" : "",
                "{{total_mensual}}": "\(totalMonthlyInt)\(currencySymbol)",
                "{{total_monthly}}": "\(totalMonthlyInt)\(currencySymbol)",
                // Legacy format: {camelCase} (single braces, camelCase)
                "{startDateShort}": fmtDate(tenant.contractStartDate),
                "{endDateShort}": fmtDate(tenant.contractEndDate),
                "{monthlyRent}": rent > 0 ? "\(rent)\(currencySymbol)" : "",
                "{depositAmount}": deposit > 0 ? "\(deposit)\(currencySymbol)" : "",
                "{depositAmountWords}": deposit > 0 ? depositWords : "",
                "{tenantName}": tenant.fullName,
                "{tenantDni}": tenant.dni ?? "",
                "{landlordName}": landlord.fullName,
                "{landlordDni}": landlord.dni,
                "{propertyAddress}": property.address,
                "{tenantCurrentAddress}": tenantAddress,
                "{currentDate}": dateFormatter.string(from: Date()),
            ]

            // 2. Process replacements
            // Normalize line endings first: templates saved from the web app may use
            // CRLF (\r\n) or lone CR (\r), which leave stray carriage returns that
            // print as spurious line breaks / boxes on some printers.
            // A placeholder with no value (empty built-in or undefined variable) is
            // rendered as a blank fill-in line so it can be completed by hand.
            let blankFill = "______________"
            var bodyText = templateBody
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            for (key, value) in replacements {
                bodyText = bodyText.replacingOccurrences(of: key, with: value.isEmpty ? blankFill : value)
            }

            // 3. Process custom variables (user-defined)
            for variable in customVariables {
                bodyText = bodyText.replacingOccurrences(
                    of: variable.templateKey,
                    with: variable.defaultValue.isEmpty ? blankFill : variable.defaultValue)
            }

            // 4. Any remaining {{placeholder}} (undefined variable) → blank fill-in line.
            bodyText = bodyText.replacingOccurrences(
                of: "\\{\\{[^}]*\\}\\}", with: blankFill, options: .regularExpression)

            // 3. Render paragraphs
            let lines = bodyText.components(separatedBy: "\n")

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // Distinct empty line → vertical spacing (next content line breaks itself)
                if trimmed.isEmpty {
                    y += 12
                    continue
                }

                // Header check (### Header or short ALL-CAPS line)
                var isHeader = false
                var displayText = trimmed
                if trimmed.hasPrefix("### ") {
                    isHeader = true
                    displayText = String(trimmed.dropFirst(4))
                } else if trimmed.count < 80 && trimmed == trimmed.uppercased() && trimmed.count > 3 {
                    isHeader = true
                }

                if isHeader {
                    let font = UIFont.boldSystemFont(ofSize: 14)
                    let h = measureHeight(displayText, font: font, maxWidth: contentWidth)
                    // Reserve the heading plus ~2 lines so it never sits orphaned at a page bottom.
                    y = checkPageBreak(y: y, needed: h + 46, context: context)
                    y = drawColoredText(
                        displayText, at: CGPoint(x: margin, y: y),
                        font: font, color: charcoal, maxWidth: contentWidth) + 8
                    continue
                }

                // Two-column row (e.g. the signature block). A tab or a run of 3+ spaces
                // marks the column gap; we lay the two parts at fixed positions because
                // padding columns with spaces does not align in a proportional font.
                if let gap = trimmed.range(of: "(\\t+| {3,})", options: .regularExpression) {
                    let left = trimmed[..<gap.lowerBound].trimmingCharacters(in: .whitespaces)
                    let right = trimmed[gap.upperBound...].trimmingCharacters(in: .whitespaces)
                    if !left.isEmpty, !right.isEmpty {
                        // A bold left part marks the start of the signature block — reserve
                        // enough height to keep the whole block (titles + lines + names) together.
                        let leftIsBold = left.hasPrefix("**") && left.hasSuffix("**")
                        y = checkPageBreak(y: y, needed: leftIsBold ? 92 : 28, context: context)
                        y = drawTwoColumns(left, right, at: y, contentWidth: contentWidth) + 4
                        continue
                    }
                }

                // Bold markers **text**
                if displayText.contains("**") {
                    let spans = parseMarkdown(displayText)
                    let h = measureMixed(spans, contentWidth: contentWidth)
                    y = checkPageBreak(y: y, needed: h, context: context)
                    y = drawMixedText(spans, at: y, contentWidth: contentWidth) + 4
                } else {
                    let h = measureHeight(displayText, font: .systemFont(ofSize: 11), maxWidth: contentWidth)
                    y = checkPageBreak(y: y, needed: h, context: context)
                    y = drawParagraph(displayText, at: y, contentWidth: contentWidth) + 4
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

    /// Measured height of a single-font text block (for accurate page breaks).
    private func measureHeight(_ text: String, font: UIFont, maxWidth: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        let attr = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: style])
        return attr.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
    }

    /// Measured height of a mixed bold/regular span run.
    private func measureMixed(_ spans: [TextSpan], contentWidth: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 11)
        let boldFont = UIFont.boldSystemFont(ofSize: 11)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        let attr = NSMutableAttributedString()
        for span in spans {
            attr.append(NSAttributedString(
                string: span.text,
                attributes: [.font: span.isBold ? boldFont : font, .paragraphStyle: style]))
        }
        return attr.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
    }

    /// Draw two columns at fixed positions (left half / right half). Used for the
    /// signature block so the right column lines up regardless of text width.
    private func drawTwoColumns(_ left: String, _ right: String, at y: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let gap: CGFloat = 24
        let colWidth = (contentWidth - gap) / 2
        let leftHeight = drawColumnPart(left, at: CGPoint(x: margin, y: y), maxWidth: colWidth)
        let rightHeight = drawColumnPart(right, at: CGPoint(x: margin + colWidth + gap, y: y), maxWidth: colWidth)
        return y + max(leftHeight, rightHeight)
    }

    /// Draw one column part, honouring a fully-bold part wrapped in `**`.
    private func drawColumnPart(_ raw: String, at point: CGPoint, maxWidth: CGFloat) -> CGFloat {
        let isBold = raw.hasPrefix("**") && raw.hasSuffix("**") && raw.count > 4
        let text = raw.replacingOccurrences(of: "**", with: "")
        let font: UIFont = isBold ? .boldSystemFont(ofSize: 11) : .systemFont(ofSize: 11)
        let endY = drawColoredText(text, at: point, font: font, color: charcoal, maxWidth: maxWidth)
        return endY - point.y
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

    // MARK: - Annual Tax Report

    func generateAnnualReport(
        year: Int, rows: [PropertyAnnualSummary],
        totalCollected: Decimal, totalPending: Decimal,
        totalExpenses: Decimal, totalNet: Decimal
    ) async -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let contentWidth = pageWidth - margin * 2

        return await Task.detached(priority: .userInitiated) { [self] in
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            return renderer.pdfData { context in
                context.beginPage()

                // Header band
                drawRect(at: CGRect(x: 0, y: 0, width: pageWidth, height: 70), color: navy, context: context)
                let title = String(localized: "Informe anual", locale: LanguageService.currentLocale, comment: "Annual report PDF title")
                drawColoredText(
                    "\(title) \(year)", at: CGPoint(x: margin, y: 22),
                    font: .boldSystemFont(ofSize: 22), color: .white, maxWidth: contentWidth)
                let df = DateFormatter()
                df.dateStyle = .long
                df.locale = LanguageService.currentLocale
                drawColoredText(
                    df.string(from: Date()), at: CGPoint(x: margin, y: 50),
                    font: .systemFont(ofSize: 10), color: UIColor.white.withAlphaComponent(0.8),
                    maxWidth: contentWidth)
                drawRect(at: CGRect(x: margin, y: 70, width: contentWidth, height: 3), color: gold, context: context)

                var y: CGFloat = 92

                // Column headers
                let col2 = margin + contentWidth * 0.46
                let col3 = margin + contentWidth * 0.68
                let col4 = margin + contentWidth * 0.86
                func headerCell(_ t: String, x: CGFloat, align: NSTextAlignment) {
                    drawColoredText(t, at: CGPoint(x: x, y: y), font: .boldSystemFont(ofSize: 9), color: .gray, maxWidth: contentWidth * 0.18, alignment: align)
                }
                drawColoredText(String(localized: "Propiedad", locale: LanguageService.currentLocale, comment: "Property column"), at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 9), color: .gray, maxWidth: contentWidth * 0.44)
                headerCell(String(localized: "Cobrado", locale: LanguageService.currentLocale, comment: "Collected column"), x: col2, align: .right)
                headerCell(String(localized: "Gastos", locale: LanguageService.currentLocale, comment: "Expenses column"), x: col3, align: .right)
                headerCell(String(localized: "Neto", locale: LanguageService.currentLocale, comment: "Net column"), x: col4, align: .right)
                y += 18
                drawRect(at: CGRect(x: margin, y: y, width: contentWidth, height: 0.5), color: .lightGray, context: context)
                y += 8

                // Rows
                for row in rows {
                    if y > pageHeight - 120 { context.beginPage(); y = margin }
                    drawColoredText(row.name, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth * 0.44)
                    drawColoredText(row.collected.formatted(currencyCode: "EUR", showDecimals: true), at: CGPoint(x: col2, y: y), font: .systemFont(ofSize: 11), color: emerald, maxWidth: contentWidth * 0.18, alignment: .right)
                    drawColoredText(row.expenses.formatted(currencyCode: "EUR", showDecimals: true), at: CGPoint(x: col3, y: y), font: .systemFont(ofSize: 11), color: UIColor.systemRed, maxWidth: contentWidth * 0.18, alignment: .right)
                    drawColoredText(row.net.formatted(currencyCode: "EUR", showDecimals: true), at: CGPoint(x: col4, y: y), font: .boldSystemFont(ofSize: 11), color: navy, maxWidth: contentWidth * 0.18, alignment: .right)
                    y += 22
                }

                // Totals box
                y += 6
                drawRect(at: CGRect(x: margin, y: y, width: contentWidth, height: 1), color: gold, context: context)
                y += 12
                func totalLine(_ label: String, _ value: Decimal, color: UIColor, bold: Bool) {
                    drawColoredText(label, at: CGPoint(x: margin, y: y), font: bold ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth * 0.6)
                    drawColoredText(value.formatted(currencyCode: "EUR", showDecimals: true), at: CGPoint(x: col4 - contentWidth * 0.1, y: y), font: bold ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 11), color: color, maxWidth: contentWidth * 0.28, alignment: .right)
                    y += bold ? 24 : 20
                }
                totalLine(String(localized: "Total cobrado", locale: LanguageService.currentLocale, comment: "Total collected"), totalCollected, color: emerald, bold: false)
                if totalPending > 0 {
                    totalLine(String(localized: "Total pendiente", locale: LanguageService.currentLocale, comment: "Total pending"), totalPending, color: UIColor.systemOrange, bold: false)
                }
                totalLine(String(localized: "Total gastos", locale: LanguageService.currentLocale, comment: "Total expenses"), totalExpenses, color: UIColor.systemRed, bold: false)
                totalLine(String(localized: "Resultado neto", locale: LanguageService.currentLocale, comment: "Net result"), totalNet, color: navy, bold: true)

                drawPremiumFooter(context: context)
            }
        }.value
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
        roomImages: [UIImage] = [], commonRoomImages: [String: [UIImage]] = [:],
        communityFeesIncludes: [String] = [], communityFeesAmount: Decimal? = nil
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

            // Status badge — text vertically centered within the pill
            let badgeText = String(localized: "FOR RENT", locale: LanguageService.currentLocale, comment: "PDF room ad status badge")
            let badgeFont = UIFont.boldSystemFont(ofSize: 10)
            let badgeWidth: CGFloat = 110
            let badgeRect = CGRect(x: margin, y: 15, width: badgeWidth, height: 24)
            drawRect(at: badgeRect, color: emerald, context: context, cornerRadius: 12)
            drawColoredText(
                badgeText,
                at: CGPoint(x: margin + 8, y: badgeRect.midY - badgeFont.lineHeight / 2),
                font: badgeFont, color: .white, maxWidth: badgeWidth - 16)

            // Price badge — text vertically centered within the pill
            let perMonth = String(localized: "/mo", locale: LanguageService.currentLocale, comment: "Per month abbreviation for rent")
            let priceText = "\(room.monthlyRent.formatted(currencyCode: "EUR"))\(perMonth)"
            let priceFont = UIFont.boldSystemFont(ofSize: 11)
            let priceWidth: CGFloat = 120
            let priceRect = CGRect(
                x: pageWidth - margin - priceWidth, y: 15, width: priceWidth, height: 24)
            drawRect(at: priceRect, color: gold, context: context, cornerRadius: 12)
            drawColoredText(
                priceText,
                at: CGPoint(x: pageWidth - margin - priceWidth + 8, y: priceRect.midY - priceFont.lineHeight / 2),
                font: priceFont, color: .white, maxWidth: priceWidth - 16, alignment: .center)

            // Title in header — generic room type (e.g. "Habitación"), not the
            // owner's internal room name. Address shown below.
            let titleText = room.roomType == .privateRoom
                ? String(localized: "Habitación", locale: LanguageService.currentLocale, comment: "PDF room ad title for private room")
                : String(localized: "Zona común", locale: LanguageService.currentLocale, comment: "PDF room ad title for common area")
            drawColoredText(
                titleText, at: CGPoint(x: margin, y: 50),
                font: .boldSystemFont(ofSize: 22), color: .white, maxWidth: contentWidth)
            drawColoredText(
                property.address, at: CGPoint(x: margin, y: 73),
                font: .systemFont(ofSize: 11), color: UIColor.white.withAlphaComponent(0.8),
                maxWidth: contentWidth)

            // Gold accent line
            drawRect(
                at: CGRect(x: margin, y: 92, width: contentWidth, height: 3), color: gold,
                context: context)
            y = 110

            // Quick features bar: size + each common area name as a chip.
            let amenities = buildAmenityChips(commonRooms: commonRooms, room: room)
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
            // Don't fake the deposit as the monthly rent — show "Ask" when it's unknown.
            let depositValue = depositAmount.map { $0.formatted(currencyCode: "EUR") }
                ?? String(localized: "Ask", locale: LanguageService.currentLocale, comment: "PDF room ad deposit value when unknown")
            drawInfoBox(
                title: depositLabel, value: depositValue,
                at: CGRect(x: margin + boxWidth + 10, y: y, width: boxWidth, height: 50),
                context: context)
            drawInfoBox(
                title: availabilityLabel, value: immediateValue,
                at: CGRect(x: margin + (boxWidth + 10) * 2, y: y, width: boxWidth, height: 50),
                context: context)
            y += 70

            // Contact — prominent, shown above the details.
            if let contact = ownerContact, !contact.isEmpty {
                let boxHeight: CGFloat = 50
                drawRect(
                    at: CGRect(x: margin, y: y, width: contentWidth, height: boxHeight),
                    color: navy, context: context, cornerRadius: 10)
                let contactLabel = String(localized: "Contact", locale: LanguageService.currentLocale, comment: "PDF room ad contact label")
                drawColoredText(
                    contactLabel, at: CGPoint(x: margin + 16, y: y + 9),
                    font: .systemFont(ofSize: 9), color: UIColor.white.withAlphaComponent(0.7),
                    maxWidth: contentWidth - 32)
                drawColoredText(
                    contact, at: CGPoint(x: margin + 16, y: y + 21),
                    font: .boldSystemFont(ofSize: 19), color: .white, maxWidth: contentWidth - 32)
                y += boxHeight + 18
            }

            // Room details section
            y = checkPageBreak(y: y, needed: 110, context: context)
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
                y = drawLabelValue(sizeLabel, value: "\(formatSize(size)) m²", at: y)
            }
            let feesAmount = communityFeesAmount ?? 0
            if feesAmount > 0 || !communityFeesIncludes.isEmpty {
                let feesLabel = String(localized: "Common expenses:", locale: LanguageService.currentLocale, comment: "PDF room ad common expenses label")
                // Format like rent/deposit (locale currency, no Int truncation, no glued symbol).
                var feesValue = feesAmount > 0 ? "\(feesAmount.formatted(currencyCode: "EUR"))\(perMonth)" : ""
                if !communityFeesIncludes.isEmpty {
                    let joined = communityFeesIncludes.joined(separator: ", ")
                    feesValue = feesValue.isEmpty ? joined : "\(feesValue) — \(joined)"
                }
                y = drawLabelValue(feesLabel, value: feesValue, at: y)
            }
            y += 10

            // Description — capped with an ellipsis (no silent loss) and paginated so it
            // never spills under the footer.
            if let notes = room.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                let capped = notes.count > 600 ? String(notes.prefix(600)) + "…" : notes
                let descTitle = String(localized: "DESCRIPTION", locale: LanguageService.currentLocale, comment: "PDF room ad description section title")
                let descHeight = measureHeight(capped, font: .systemFont(ofSize: 11), maxWidth: contentWidth)
                y = checkPageBreak(y: y, needed: 36 + descHeight, context: context)
                y = drawPremiumSectionTitle(descTitle, at: y)
                y = drawColoredText(
                    capped, at: CGPoint(x: margin, y: y),
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

            // Common areas. Start on a fresh page only if some common room actually has
            // photos; otherwise continue inline so we don't waste a blank page on bare names.
            if !commonRooms.isEmpty {
                let anyCommonPhotos = commonRooms.contains { !(commonRoomImages[$0.id.uuidString]?.isEmpty ?? true) }
                if anyCommonPhotos {
                    context.beginPage()
                    y = margin
                } else {
                    y = checkPageBreak(y: y, needed: 70, context: context)
                }
                let commonTitle = String(localized: "COMMON AREAS", locale: LanguageService.currentLocale, comment: "PDF room ad common areas section title")
                y = drawPremiumSectionTitle(commonTitle, at: y)
                for commonRoom in commonRooms {
                    let photos = commonRoomImages[commonRoom.id.uuidString] ?? []
                    // Keep each label with its photos: jump to the next page if it won't fit.
                    let needed: CGFloat = photos.isEmpty ? 26 : 190
                    if y + needed > pageHeight - 60 {
                        context.beginPage()
                        y = margin
                    }
                    y = drawBulletPoint("• \(commonRoom.name)", at: y, context: context)
                    if !photos.isEmpty {
                        y = drawPhotoGrid(photos, at: y, contentWidth: contentWidth, context: context)
                        y += 8
                    }
                }
                y += 10
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
            // Cap to the content width so a very long common-room name can't bleed past the margin.
            let textWidth = min(
                amenity.size(withAttributes: [.font: UIFont.systemFont(ofSize: 9)]).width + 16,
                contentWidth)
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

    /// Quick-feature chips for the ad header: the room size plus every common area by its
    /// actual name (deduped). Not "detection" — it just lists what the property has.
    private func buildAmenityChips(commonRooms: [Room], room: Room) -> [String] {
        var chips: [String] = []
        if let size = room.sizeSqm { chips.append("\(formatSize(size)) m²") }
        for common in commonRooms {
            let name = common.name.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, !chips.contains(name) {
                chips.append(name)
            }
        }
        return chips
    }

    /// Locale-aware size string (e.g. "12,5") without trailing decimal noise.
    private func formatSize(_ size: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = LanguageService.currentLocale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: size as NSDecimalNumber) ?? "\(size)"
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
        dateFormatter.locale = LanguageService.currentLocale
        let dateStr = dateFormatter.string(from: Date())
        let footerText = String(localized: "Generated with Rental Manager", locale: LanguageService.currentLocale, comment: "PDF footer text")
        drawColoredText(
            "\(footerText) · \(dateStr)", at: CGPoint(x: margin, y: footerY),
            font: .italicSystemFont(ofSize: 8), color: .gray, maxWidth: contentWidth,
            alignment: .center)
    }

    // MARK: - Core Drawing

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

    private func drawLabelValue(_ label: String, value: String, at yPosition: CGFloat) -> CGFloat {
        let labelWidth: CGFloat = 130
        let contentWidth = pageWidth - margin * 2
        let labelEnd = drawColoredText(
            label, at: CGPoint(x: margin, y: yPosition),
            font: .boldSystemFont(ofSize: 11), color: charcoal, maxWidth: labelWidth)
        let valueEnd = drawColoredText(
            value, at: CGPoint(x: margin + labelWidth, y: yPosition),
            font: .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth - labelWidth)
        // Advance by the taller of the two columns so a wrapped label can't overlap the next row.
        return max(labelEnd, valueEnd) + 4
    }

}
