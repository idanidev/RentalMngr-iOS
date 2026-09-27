import SwiftUI

/// Cómo se representa una casa que se alquila entera.
///
/// En la base, el inquilino y la renta cuelgan siempre de una habitación: no hay
/// otro sitio donde ponerlos. Una casa entera necesita por tanto **una** por
/// debajo, que hace de "la casa". Aquí se decide cuál es y cuándo crearla; la
/// interfaz nunca la llama habitación.
enum WholeHome {
    /// Nombre de la unidad. Es lo que sale de título al entrar en ella.
    static var unitName: String {
        String(localized: "Vivienda completa", locale: LanguageService.currentLocale,
            comment: "Name of the hidden unit that represents a whole-home rental")
    }

    /// Qué registro hace de la casa.
    ///
    /// La habitación privada que tenga inquilino, y si ninguna lo tiene, la
    /// primera privada. Lo normal es que haya una sola, la creada al marcar la
    /// casa como entera; varias solo aparecen si un piso compartido se pasa a
    /// casa entera, y entonces manda la que ya estaba alquilada.
    static func unit(in rooms: [Room]) -> Room? {
        let privadas = rooms.filter { $0.roomType == .privateRoom }
        return privadas.first { $0.tenantId != nil || $0.occupied } ?? privadas.first
    }

    /// Lo que queda aparte de la unidad: habitaciones de cuando se alquilaba por
    /// habitaciones. No se borran nunca solas; se enseñan aparte.
    static func others(in rooms: [Room], besides unit: Room?) -> [Room] {
        rooms.filter { $0.id != unit?.id }
    }

    /// Si al guardar hay que crear la unidad.
    ///
    /// Solo con la casa vacía. Si ya tenía habitaciones —un piso compartido que
    /// pasa a casa entera— se usan las que hay: crear otra dejaría dos candidatas
    /// a "la casa" y ninguna forma clara de elegir.
    static func needsUnit(isSingleUnit: Bool, existingRooms: Int) -> Bool {
        isSingleUnit && existingRooms == 0
    }
}

/// La pestaña Vivienda de una casa que se alquila entera: renta, inquilino y
/// estado de un vistazo, sin habitaciones de por medio.
struct WholeHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var hSize
    let propertyId: UUID
    let rooms: [Room]
    /// Recarga la propiedad. Se llama al crear la unidad y al volver de editarla,
    /// para que la tarjeta no enseñe una renta vieja.
    let onChange: () async -> Void

    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var hasAppeared = false

    /// Un único gutter por pantalla (MAC_DESIGN §1): regular 20, compacto 16.
    private var gutter: CGFloat { hSize == .regular ? 20 : 16 }
    private var unit: Room? { WholeHome.unit(in: rooms) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let unit {
                NavigationLink {
                    RoomDetailView(room: unit, isWholeHome: true)
                } label: {
                    card(unit)
                }
                .buttonStyle(.plain)

                leftovers(besides: unit)
            } else {
                EmptyStateView(
                    icon: "house",
                    title: String(localized: "Aún no tiene renta ni inquilino",
                        locale: LanguageService.currentLocale,
                        comment: "Whole home without unit: title"),
                    subtitle: String(localized: "Prepárala para poder ponerle la renta y asignar a quien la alquila.",
                        locale: LanguageService.currentLocale,
                        comment: "Whole home without unit: subtitle"),
                    actionTitle: isCreating
                        ? nil
                        : String(localized: "Preparar vivienda",
                            locale: LanguageService.currentLocale,
                            comment: "Whole home without unit: action"),
                    action: { Task { await createUnit() } }
                )
                .overlay { if isCreating { ProgressView() } }
            }
        }
        .padding(.horizontal, gutter)
        .errorAlert($errorMessage, context: "Vivienda")
        .onAppear {
            // La primera vez los datos acaban de llegar del padre; al volver de
            // la ficha pueden haber cambiado la renta o el inquilino.
            if hasAppeared { Task { await onChange() } }
            hasAppeared = true
        }
    }

    // MARK: - Tarjeta

    private func card(_ unit: Room) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label(WholeHome.unitName, systemImage: "house.fill")
                    .font(.headline)
                Spacer()
                statusPill(occupied: unit.occupied)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(unit.monthlyRent.formatted(currencyCode: "EUR"))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text(String(localized: "al mes", locale: LanguageService.currentLocale,
                    comment: "Rent period, whole home card"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Image(systemName: unit.tenantName == nil ? "person.badge.plus" : "person.fill")
                    .foregroundStyle(.secondary)
                Text(unit.tenantName ?? String(localized: "Sin inquilino",
                    locale: LanguageService.currentLocale,
                    comment: "Whole home card: no tenant yet"))
                    .foregroundStyle(unit.tenantName == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline)

            if unit.monthlyRent == 0 {
                // Una casa recién creada tiene renta 0. Sin esta pista la tarjeta
                // enseña "0 €" y no dice qué hacer.
                Text(String(localized: "Toca para poner la renta y asignar inquilino.",
                    locale: LanguageService.currentLocale,
                    comment: "Whole home card hint when rent is not set"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "Abre la renta, el inquilino y el inventario",
            locale: LanguageService.currentLocale, comment: "Whole home card accessibility hint"))
    }

    private func statusPill(occupied: Bool) -> some View {
        Text(occupied
            ? String(localized: "Alquilada", locale: LanguageService.currentLocale,
                comment: "Whole home status: rented")
            : String(localized: "Libre", locale: LanguageService.currentLocale,
                comment: "Whole home status: available"))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(occupied ? .green : .orange)
            .background((occupied ? Color.green : Color.orange).opacity(0.15), in: Capsule())
    }

    // MARK: - Lo que sobra de cuando era por habitaciones

    @ViewBuilder
    private func leftovers(besides unit: Room) -> some View {
        let otras = WholeHome.others(in: rooms, besides: unit)
        if !otras.isEmpty {
            // No se borran: pueden tener inventario o historial. Se dicen y se
            // dejan a mano, que es quien decide.
            NavigationLink {
                RoomListView(propertyId: propertyId, rooms: otras)
                    .navigationTitle(String(localized: "Estancias guardadas",
                        locale: LanguageService.currentLocale,
                        comment: "Title for leftover rooms of a whole home"))
            } label: {
                Label(
                    String(localized: "\(otras.count) estancias guardadas de cuando se alquilaba por habitaciones",
                        locale: LanguageService.currentLocale,
                        comment: "Link to leftover rooms in a whole home"),
                    systemImage: "square.stack")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Crear la unidad

    private func createUnit() async {
        isCreating = true
        defer { isCreating = false }
        do {
            _ = try await appState.roomService.createRoom(
                propertyId: propertyId, name: WholeHome.unitName,
                monthlyRent: 0, roomType: .privateRoom, sizeSqm: nil)
            await onChange()
        } catch where error.isCancellation {
            // Salir de la pantalla cancela la tarea; no es un fallo.
        } catch {
            errorMessage = error.safeUserMessage
        }
    }
}
