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

    func generateContract(tenant: Tenant, room: Room, property: Property) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let contentWidth = pageWidth - margin * 2

        // Format helpers
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.locale = Locale(identifier: "es_ES")

        func fmtDate(_ date: Date?) -> String {
            guard let d = date else { return "" }
            return dateFormatter.string(from: d)
        }

        let rent = Int(truncating: room.monthlyRent as NSDecimalNumber)
        let deposit = Int(truncating: (tenant.depositAmount ?? 0) as NSDecimalNumber)
        let depositWords = Self.numberToWords(deposit).uppercased()
        let tenantAddress = tenant.currentAddress ?? property.address
        let contractDate = dateFormatter.string(from: Date())

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            // MARK: — Title
            y =
                drawColoredText(
                    "CONTRATO DE ARRENDAMIENTO DE HABITACIÓN EN PISO COMPARTIDO.",
                    at: CGPoint(x: margin, y: y),
                    font: .boldSystemFont(ofSize: 16), color: navy, maxWidth: contentWidth) + 12

            // MARK: — Date & Place
            y =
                drawMixedText(
                    [
                        .regular("En Guadalajara a "), .bold(contractDate),
                    ], at: y, contentWidth: contentWidth) + 4
            y =
                drawColoredText(
                    "Estamos reunidos:", at: CGPoint(x: margin, y: y),
                    font: .systemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth) + 8

            // MARK: — Landlord
            y =
                drawColoredText(
                    "COMO PARTE ARRENDADORA:", at: CGPoint(x: margin, y: y),
                    font: .boldSystemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth) + 4
            y =
                drawMixedText(
                    [
                        .regular("Doña "), .bold("M.ª Ángeles Díaz Trillo"),
                        .regular(
                            ", mayor de edad y titular del DNI "),
                        .bold("03093405C"),
                        .regular(
                            ". Propietaria de la vivienda compartida situada en "),
                        .bold(property.address), .regular("."),
                    ], at: y, contentWidth: contentWidth) + 8

            // MARK: — Tenant
            y =
                drawColoredText(
                    "COMO PARTE ARRENDATARIA:", at: CGPoint(x: margin, y: y),
                    font: .boldSystemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth) + 4
            y =
                drawMixedText(
                    [
                        .regular("D/Dña. "), .bold(tenant.fullName),
                        .regular(" mayor de edad con DNI/PASAPORTE "),
                        .bold(tenant.dni ?? "___________"),
                        .regular(" Y con domicilio en "), .bold(tenantAddress),
                    ], at: y, contentWidth: contentWidth) + 12

            // MARK: — Agreement
            y =
                drawColoredText(
                    "AMBAS PARTES CONVIENEN EL ARRIENDO DE LA HABITACIÓN",
                    at: CGPoint(x: margin, y: y),
                    font: .boldSystemFont(ofSize: 12), color: charcoal, maxWidth: contentWidth) + 4
            y =
                drawMixedText(
                    [
                        .regular("Que se inicia el día "), .bold(fmtDate(tenant.contractStartDate)),
                        .regular(" finalizando el día "), .bold(fmtDate(tenant.contractEndDate)),
                        .regular(". El precio del arriendo es de "), .bold("\(rent)€"),
                        .regular(
                            " mensuales, estando incluidos los gastos a excepción de calefacción y electricidad que deberán ser abonados de la siguiente forma, a dividir entre todos los ocupantes de la vivienda."
                        ),
                    ], at: y, contentWidth: contentWidth) + 6

            // Deposit
            y = checkPageBreak(y: y, needed: 60, context: context)
            y =
                drawMixedText(
                    [
                        .regular(
                            "EL DEPÓSITO que, como garantía deberá abonar el ARRENDATARIO es de "),
                        .bold("\(deposit)€"), .regular(" ("),
                        .bold("\(depositWords) EUROS"),
                        .regular(
                            "), importe que le será devuelto al finalizar el contrato, bien en metálico bien por transferencia bancaria."
                        ),
                    ], at: y, contentWidth: contentWidth) + 6

            // Receipt clause
            y = checkPageBreak(y: y, needed: 40, context: context)
            y =
                drawParagraph(
                    "Este contrato no tiene validez como justificante de pago del arriendo, EL ARRENDADOR le deberá entregar al ARRENDATARIO un recibo como justificante de pago.",
                    at: y, contentWidth: contentWidth) + 6

            // Scope
            y = checkPageBreak(y: y, needed: 50, context: context)
            y =
                drawParagraph(
                    "El objeto del ARRIENDO ES EXCLUSIVAMENTE la habitación que se indica, sin derecho a utilizar otros dormitorios de la casa. En cuanto al resto del mismo, EL ARRENDADOR acepta compartir el uso de la cocina, salón, y baño común para lo que se obliga a las normas de respeto y buena convivencia.",
                    at: y, contentWidth: contentWidth) + 12

            // MARK: — Landlord Access
            y = checkPageBreak(y: y, needed: 80, context: context)
            y =
                drawColoredText(
                    "DERECHO DE ACCESO A LA VIVIENDA DEL ARRENDADOR.",
                    at: CGPoint(x: margin, y: y),
                    font: .boldSystemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth) + 4
            y =
                drawParagraph(
                    "Las partes acuerdan expresamente la renuncia del arrendatario a impedir que el arrendador pueda acceder a las zonas comunes de la vivienda. La violación de este derecho del arrendador por parte de cualquier persona que se encuentre en la vivienda será considerada causa de disolución del contrato y motivo de desahucio del arrendatario, siendo este responsable de los daños y perjuicios que el impedimento del acceso pueda ocasionar al arrendador, entre otros la perdida de beneficios por no poder arrendar otras habitaciones.",
                    at: y, contentWidth: contentWidth) + 8

            // MARK: — Notice Period
            y = checkPageBreak(y: y, needed: 80, context: context)
            y =
                drawColoredText(
                    "CLÁUSULA DE PREAVISO Y PERMANENCIA MENSUAL",
                    at: CGPoint(x: margin, y: y),
                    font: .boldSystemFont(ofSize: 11), color: charcoal, maxWidth: contentWidth) + 4
            y =
                drawParagraph(
                    "En caso de que el ARRENDATARIO desee dar por finalizado el contrato antes de su fecha de vencimiento, deberá comunicarlo al ARRENDADOR con un mínimo de 15 días naturales de antelación.",
                    at: y, contentWidth: contentWidth) + 4
            y =
                drawParagraph(
                    "No obstante, aunque se haya dado el preaviso dentro de ese plazo, el ARRENDATARIO estará obligado a abonar la mensualidad completa del mes en el que abandone la habitación, no correspondiendo, en ningún caso, el prorrateo de dicho importe.",
                    at: y, contentWidth: contentWidth) + 8

            // MARK: — Termination
            y = checkPageBreak(y: y, needed: 80, context: context)
            y =
                drawParagraph(
                    "EL ARRENDADOR podrá rescindir el contrato UNILATERALMENTE DE FORMA INMEDIATA si existen faltas en las normas del piso, o de buena convivencia entre compañeros o con el vecindario de la casa, o bien si estuviera en situación de falta de pago de la renta o suministros y/o calefacción, como también si existiera incumplimiento de cualquiera de los términos del contrato.",
                    at: y, contentWidth: contentWidth) + 4
            y =
                drawParagraph(
                    "EL ARRENDADOR se reserva el derecho de rescindir el contrato por cualquier causa diferente a las anteriores siempre y cuando lo comunique al arrendatario con un mes de antelación.",
                    at: y, contentWidth: contentWidth) + 6

            // Prohibitions
            y = checkPageBreak(y: y, needed: 40, context: context)
            y =
                drawParagraph(
                    "Queda prohibida la introducción de terceras personas sin previo aviso al arrendador, la contratación de ningún tipo de servicios, así como la cesión PARCIAL o TOTAL de este contrato, sin previo permiso escrito de la propiedad.",
                    at: y, contentWidth: contentWidth) + 4
            y =
                drawParagraph(
                    "El contrato no se podrá ceder ni subarrendar de forma parcial por el arrendatario sin previo consentimiento por escrito del arrendador.",
                    at: y, contentWidth: contentWidth) + 4
            y =
                drawParagraph(
                    "No se permite fumar en el interior de la casa, ya que dispone de zonas, como el patio, en las que se puede fumar sin molestar al resto de inquilinos.",
                    at: y, contentWidth: contentWidth) + 4

            // Quiet hours
            y = checkPageBreak(y: y, needed: 40, context: context)
            y =
                drawParagraph(
                    "EL ARRENDATARIO está obligado a cumplir las normas de la casa, respetando el descanso de todos los que habitan la casa, especialmente desde las 23:00 hasta las 8:00.",
                    at: y, contentWidth: contentWidth) + 4

            // Property condition
            y = checkPageBreak(y: y, needed: 60, context: context)
            y =
                drawParagraph(
                    "EL ARRENDATARIO declara que el piso está en buen estado, obligándose a conservar todo con la mayor diligencia y a abonar los desperfectos que no sean debidos a un uso normal y correcto. Al finalizar el contrato, se comprobará que haya habido una correcta conservación de la casa y mobiliario. Siendo objeto de arriendo exclusivamente la habitación expresada, la propiedad conserva su derecho a entrar y salir de la casa por lo que el arrendatario se obliga a no cambiar la cerradura de la puerta. Por pérdida de llaves se abonará su importe.",
                    at: y, contentWidth: contentWidth) + 4

            y = checkPageBreak(y: y, needed: 40, context: context)
            y =
                drawParagraph(
                    "Queda terminantemente PROHIBIDA cualquier obra o alteración en el piso, sin previo permiso por escrito de la propiedad, así como la entrada de animales en el piso.",
                    at: y, contentWidth: contentWidth) + 4
            y =
                drawParagraph(
                    "EL ARRENDADOR no se hace responsable de pérdidas o hurtos en las habitaciones. A tal efecto todas las habitaciones tienen cerradura privada.",
                    at: y, contentWidth: contentWidth) + 4
            y =
                drawParagraph(
                    "EL ARRENDADOR tampoco se hace responsable de los posibles daños que pudieran surgir en los dispositivos eléctricos ajenos enchufados en la red eléctrica del piso.",
                    at: y, contentWidth: contentWidth) + 4
            y =
                drawParagraph(
                    "Y en prueba de conformidad con todo cuanto antecede, firman ambas partes en lugar y fecha indicados.",
                    at: y, contentWidth: contentWidth) + 20

            // MARK: — Signatures
            y = checkPageBreak(y: y, needed: 80, context: context)
            let sigWidth = (contentWidth - 40) / 2
            drawColoredText(
                "EL ARRENDADOR", at: CGPoint(x: margin, y: y),
                font: .boldSystemFont(ofSize: 11), color: navy, maxWidth: sigWidth,
                alignment: .center)
            drawColoredText(
                "EL ARRENDATARIO", at: CGPoint(x: margin + sigWidth + 40, y: y),
                font: .boldSystemFont(ofSize: 11), color: navy, maxWidth: sigWidth,
                alignment: .center)
            y += 35
            let ctx = context.cgContext
            ctx.setStrokeColor(charcoal.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: margin + 10, y: y))
            ctx.addLine(to: CGPoint(x: margin + sigWidth - 10, y: y))
            ctx.move(to: CGPoint(x: margin + sigWidth + 50, y: y))
            ctx.addLine(to: CGPoint(x: pageWidth - margin - 10, y: y))
            ctx.strokePath()

            // MARK: — Page 2: House Rules
            context.beginPage()
            y = margin

            y =
                drawColoredText(
                    "NORMAS DE RESPETO Y BUENA CONVIVENCIA",
                    at: CGPoint(x: margin, y: y),
                    font: .boldSystemFont(ofSize: 14), color: navy, maxWidth: contentWidth) + 12

            let normas = [
                "Repartir y asignar las distintas tareas del hogar. De esta manera, evitarás en la medida de lo posible las discusiones. Dejarlo a la buena voluntad de cada uno no funciona.",
                "Dejar lo más limpio y presentable posible las habitaciones comunes, como el baño o la cocina.",
                "Establecer unos horarios de silencio ya que se puede molestar a algunos compañeros que tengan que trabajar. Horario mínimo a respetar de 23h a 8h, no usar la lavadora ni el lavavajillas ni ningún otro electrodoméstico que haga ruido a partir de las 23h.",
                "Se recomienda no mostrar actitudes demasiado impositivas o irritantes porque puedes acabar perdiendo compañeros o no encontrando piso.",
                "En el caso de que alguien fume, NUNCA se hará en el interior de la casa, se hará en el patio o terraza.",
                "Se recomienda la aportación de un fondo común para la comprar de productos de uso común como lavavajillas, papel higiénico, detergente para la lavadora etc.",
                "No manipular ni el calentador ni estufa de pellet avisar en caso de que no funcione correctamente.",
                "Frigorífico: Organizar el espacio en función de los compañeros que haya. Limpiar el interior al menos una vez al mes.",
                "No acumular basura dentro de la casa, imprescindible tirarla a diario.",
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
                        "CONDICIONES PARTICULARES",
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
        let fullText = spans.map(\.text).joined()
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

    // MARK: - Number to Words (Spanish)

    static func numberToWords(_ num: Int) -> String {
        let ones = ["", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve"]
        let specials = [
            "diez", "once", "doce", "trece", "catorce", "quince",
            "dieciséis", "diecisiete", "dieciocho", "diecinueve",
        ]
        let tens = [
            "", "", "veinte", "treinta", "cuarenta", "cincuenta",
            "sesenta", "setenta", "ochenta", "noventa",
        ]
        let hundreds = [
            "", "ciento", "doscientos", "trescientos", "cuatrocientos",
            "quinientos", "seiscientos", "setecientos", "ochocientos", "novecientos",
        ]

        if num == 0 { return "cero" }
        if num < 10 { return ones[num] }
        if num < 20 { return specials[num - 10] }
        if num < 100 {
            let t = num / 10
            let o = num % 10
            return tens[t] + (o > 0 ? " y \(ones[o])" : "")
        }
        if num == 100 { return "cien" }
        if num < 1000 {
            let h = num / 100
            let remainder = num % 100
            return hundreds[h] + (remainder > 0 ? " \(numberToWords(remainder))" : "")
        }
        if num == 1000 { return "mil" }
        if num < 2000 {
            return "mil \(numberToWords(num - 1000))"
        }
        if num < 1_000_000 {
            let thousands = num / 1000
            let remainder = num % 1000
            let prefix = numberToWords(thousands) + " mil"
            return remainder > 0 ? "\(prefix) \(numberToWords(remainder))" : prefix
        }
        return "\(num)"
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
