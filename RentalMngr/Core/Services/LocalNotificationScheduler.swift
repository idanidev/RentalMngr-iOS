import Foundation
import UserNotifications
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "LocalNotifScheduler")

/// Local-only notification preference keys (AppStorage / UserDefaults).
/// These toggles live on-device only — they are NOT synced to Supabase.
enum LocalNotifPrefKey {
    static let rentReminder = "notifRentReminder"
    static let depositPending = "notifDepositPending"
    static let vacantRoom = "notifVacantRoom"
    static let weeklyReportWeekday = "weeklyReportWeekday"
}

/// Centralised (re)scheduling of every local OS notification, computed from current app data.
///
/// Runs at launch and on every foreground so the schedule never drifts, respects the
/// iOS 64-pending-notification limit (soonest-first budgeting), and reads per-type toggles
/// from `UserDefaults`. Replaces the scattered `schedule*` calls previously made at launch.
@MainActor
final class LocalNotificationScheduler {
    private let propertyService: PropertyServiceProtocol
    private let tenantService: TenantServiceProtocol
    private let roomService: RoomServiceProtocol
    private let notificationService: NotificationServiceProtocol

    /// iOS caps pending local notifications at 64. Leave headroom for safety.
    private let pendingLimit = 60
    /// Hour of day used for condition-based summary reminders (deposit, vacant room).
    private let summaryHour = 9

    init(
        propertyService: PropertyServiceProtocol,
        tenantService: TenantServiceProtocol,
        roomService: RoomServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.propertyService = propertyService
        self.tenantService = tenantService
        self.roomService = roomService
        self.notificationService = notificationService
    }

    /// Registers the default ON values for the local toggles so a fresh install behaves
    /// like every type is enabled. Must run before any `UserDefaults.bool(forKey:)` read.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            LocalNotifPrefKey.rentReminder: true,
            LocalNotifPrefKey.depositPending: true,
            LocalNotifPrefKey.vacantRoom: true,
        ])
    }

    /// Rebuilds the entire local-notification schedule from scratch.
    /// Idempotent: clears all pending requests first, then re-adds the current set.
    func rescheduleAll(userId: UUID?) async {
        let center = UNUserNotificationCenter.current()

        // Only schedule when the user has actually granted permission.
        let authStatus = await center.notificationSettings().authorizationStatus
        guard authStatus == .authorized || authStatus == .provisional else {
            logger.info("Skipping reschedule — notifications not authorized (\(authStatus.rawValue))")
            return
        }

        // Never wipe the existing schedule while auth is still resolving (nil userId) —
        // a signed-out state is handled elsewhere.
        guard userId != nil else {
            logger.info("Skipping reschedule — auth session not resolved yet (nil userId)")
            return
        }

        let defaults = UserDefaults.standard
        let now = Date()
        let calendar = Calendar.current

        // Todo lo que viene del servidor se descarga ANTES de tocar la agenda, y si
        // algo falla se deja como estaba. Antes cada descarga iba con `try?` y un
        // fallo daba una lista vacía: luego se borraban todos los avisos pendientes
        // y no se programaba ninguno. Sin conexión —o con el servidor pausado— cada
        // vuelta a la app borraba los avisos de fin de contrato.
        let serverSettings: NotificationSettings?
        let properties: [Property]
        let activeTenants: [Tenant]
        do {
            if let userId {
                serverSettings = try await notificationService.fetchOrCreateSettings(userId: userId)
            } else {
                serverSettings = nil
            }
            properties = try await propertyService.fetchProperties()
            activeTenants = properties.isEmpty
                ? []
                : try await tenantService.fetchActiveTenants(propertyIds: properties.map(\.id))
        } catch {
            logger.notice("Reprogramación aplazada: no se pudieron cargar los datos (\(error.localizedDescription)). Se mantienen los avisos actuales.")
            return
        }

        var repeating: [UNNotificationRequest] = []
        var oneShots: [(date: Date, request: UNNotificationRequest)] = []

        // 1. Monthly rent reminder (repeating) — local toggle.
        if defaults.bool(forKey: LocalNotifPrefKey.rentReminder) {
            repeating.append(makeRentReminderRequest())
        }

        // Scan data once: tenants + rooms per property.
        let contractAlertsEnabled = serverSettings?.enableContractAlerts ?? true
        let alertDays = serverSettings?.contractAlertDays ?? [30, 15, 7]
        let depositEnabled = defaults.bool(forKey: LocalNotifPrefKey.depositPending)
        let vacantEnabled = defaults.bool(forKey: LocalNotifPrefKey.vacantRoom)

        var depositPendingCount = 0
        var vacantRoomCount = 0

        // Una sola consulta para todas las propiedades: antes era una por cada
        // una, y esto corre en CADA vuelta a primer plano.
        let tenantsByProperty = Dictionary(grouping: activeTenants, by: \.propertyId)

        // Cifras del resumen semanal. Se cuentan siempre, aunque el aviso de
        // fianzas o el de libres estén apagados: el resumen es otro aviso.
        var weeklyOccupied = 0
        var weeklyTotal = 0
        var weeklyDepositsPending = 0

        for property in properties {
            let tenants = tenantsByProperty[property.id] ?? []

            for tenant in tenants {
                // 3. Contract expiry one-shots.
                if contractAlertsEnabled, let endDate = tenant.contractEndDate {
                    for days in alertDays {
                        guard
                            let triggerDate = calendar.date(byAdding: .day, value: -days, to: endDate),
                            triggerDate > now
                        else { continue }
                        oneShots.append(
                            (triggerDate,
                             makeContractExpiryRequest(
                                tenant: tenant, days: days, triggerDate: triggerDate)))
                    }
                }

                // Deposit-pending condition: active tenant with a contract but no deposit recorded.
                if hasContract(tenant), isDepositMissing(tenant) {
                    weeklyDepositsPending += 1
                    if depositEnabled { depositPendingCount += 1 }
                }
            }

            weeklyOccupied += property.occupiedPrivateRooms.count
            weeklyTotal += property.privateRooms.count

            if vacantEnabled {
                // Solo habitaciones que se alquilan. Antes contaba todo lo que no
                // estuviera ocupado, zonas comunes incluidas: la cocina, el salón y
                // el baño nunca se marcan como ocupados, así que salían como
                // "disponibles para alquilar" y el aviso decía 10 con todo lleno.
                // Es la misma cuenta que el panel de inicio.
                vacantRoomCount += property.vacantPrivateRooms.count
            }
        }

        // 2. Weekly report (repeating) — server toggle. Va después del recorrido
        // porque lleva las cifras dentro.
        if serverSettings?.enableWeeklyReport == true {
            let weekday = defaults.object(forKey: LocalNotifPrefKey.weeklyReportWeekday) as? Int ?? 2
            repeating.append(makeWeeklyReportRequest(
                weekday: weekday,
                body: Self.weeklySummaryBody(
                    occupied: weeklyOccupied, total: weeklyTotal,
                    depositsPending: weeklyDepositsPending)))
        }

        // 4. Condition summaries — fire at the next 9:00 if the condition currently holds.
        if depositEnabled, depositPendingCount > 0, let date = nextSummaryDate(now: now, calendar: calendar) {
            oneShots.append((date, makeDepositSummaryRequest(count: depositPendingCount, date: date, calendar: calendar)))
        }
        if vacantEnabled, vacantRoomCount > 0, let date = nextSummaryDate(now: now, calendar: calendar) {
            oneShots.append((date, makeVacantRoomSummaryRequest(count: vacantRoomCount, date: date, calendar: calendar)))
        }

        // El aviso de fin de prueba lo programa la compra, no este método: hay que
        // conservarlo o el borrado de abajo lo eliminaría en el siguiente foreground,
        // y ese aviso es lo que evita un cargo sorpresa.
        let trialReminder = await center.pendingNotificationRequests()
            .first { $0.identifier == Self.trialEndingId }

        // Clean slate, then add within the 64-pending budget (repeating first, then soonest one-shots).
        center.removeAllPendingNotificationRequests()

        if let trialReminder {
            await add(trialReminder, to: center)
        }

        var scheduled = 0
        for request in repeating {
            await add(request, to: center)
            scheduled += 1
        }

        let budget = max(0, pendingLimit - scheduled)
        let sortedOneShots = oneShots.sorted { $0.date < $1.date }
        for entry in sortedOneShots.prefix(budget) {
            await add(entry.request, to: center)
            scheduled += 1
        }

        let omitted = sortedOneShots.count - min(sortedOneShots.count, budget)
        if omitted > 0 {
            logger.notice("Reached pending-notification budget — omitted \(omitted) of \(sortedOneShots.count) dated reminders")
        }
        logger.info("Rescheduled \(scheduled) local notifications (deposit:\(depositPendingCount) vacant:\(vacantRoomCount))")
    }

    // MARK: - Conditions

    private func hasContract(_ tenant: Tenant) -> Bool {
        tenant.contractStartDate != nil || tenant.contractEndDate != nil
    }

    private func isDepositMissing(_ tenant: Tenant) -> Bool {
        guard let deposit = tenant.depositAmount else { return true }
        return deposit <= 0
    }

    /// Today at `summaryHour` if still in the future, otherwise tomorrow at `summaryHour`.
    private func nextSummaryDate(now: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(
            after: now,
            matching: DateComponents(hour: summaryHour, minute: 0),
            matchingPolicy: .nextTime)
    }

    // MARK: - Fin de prueba gratuita

    /// Avisa el día ANTES de que termine la prueba, no el mismo día: el objetivo
    /// es que dé tiempo a cancelar sin que se cobre. Un cargo sorpresa es una
    /// disputa y una reseña de una estrella.
    ///
    /// Se programa como aviso único y sobreescribe cualquier anterior, así que
    /// llamarlo varias veces es seguro.
    func scheduleTrialEndingReminder(trialEnds: Date) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.trialEndingId])

        guard let fireDate = Calendar.current.date(byAdding: .day, value: -1, to: trialEnds),
              fireDate > Date() else {
            // Prueba de un solo día (o ya vencida): no hay hueco para avisar antes.
            logger.debug("Trial too short to schedule an advance reminder")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Tu prueba acaba mañana", locale: LanguageService.currentLocale, comment: "Trial ending notification title")
        content.body = String(localized: "Puedes cancelar hoy desde Ajustes y no se te cobrará nada.", locale: LanguageService.currentLocale, comment: "Trial ending notification body")
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        await add(
            UNNotificationRequest(identifier: Self.trialEndingId, content: content, trigger: trigger),
            to: center)
    }

    /// Identificador estable para poder reemplazar el aviso sin duplicarlo.
    static let trialEndingId = "trial_ending"

    // MARK: - Request builders

    private func makeRentReminderRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Rent Collection", locale: LanguageService.currentLocale, comment: "Notification title for monthly rent reminder")
        content.body = String(localized: "Remember to check this month's rent payments.", locale: LanguageService.currentLocale, comment: "Notification body for monthly rent reminder")
        content.sound = .default

        var components = DateComponents()
        components.day = 1
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: "rent_reminder", content: content, trigger: trigger)
    }

    /// Lo que dice el resumen semanal.
    ///
    /// Un aviso local no puede consultar datos cuando salta, así que las cifras
    /// son las de la última vez que se abrió la app, que es cuando se reprograma.
    /// Cuentan como el panel de inicio: solo habitaciones que se alquilan, sin
    /// zonas comunes.
    static func weeklySummaryBody(occupied: Int, total: Int, depositsPending: Int) -> String {
        let locale = LanguageService.currentLocale
        guard total > 0 else {
            return String(localized: "Todavía no tienes habitaciones dadas de alta.",
                locale: locale, comment: "Weekly summary when there are no rooms")
        }
        var partes = [String(localized: "\(occupied) de \(total) alquiladas.",
            locale: locale, comment: "Weekly summary: rented rooms out of total")]

        let libres = total - occupied
        if libres == 0 {
            partes.append(String(localized: "Todo ocupado.", locale: locale,
                comment: "Weekly summary: nothing vacant"))
        } else if libres == 1 {
            partes.append(String(localized: "1 libre.", locale: locale,
                comment: "Weekly summary: one vacant room"))
        } else {
            partes.append(String(localized: "\(libres) libres.", locale: locale,
                comment: "Weekly summary: vacant rooms"))
        }

        if depositsPending == 1 {
            partes.append(String(localized: "1 fianza pendiente.", locale: locale,
                comment: "Weekly summary: one pending deposit"))
        } else if depositsPending > 1 {
            partes.append(String(localized: "\(depositsPending) fianzas pendientes.",
                locale: locale, comment: "Weekly summary: pending deposits"))
        }
        return partes.joined(separator: " ")
    }

    private func makeWeeklyReportRequest(weekday: Int, body: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Weekly summary", locale: LanguageService.currentLocale, comment: "Toggle title for weekly report notification")
        // Antes el cuerpo era el texto del ajuste ("Occupancy, income… every Monday
        // at 9:00 AM"): ni una cifra, y decía lunes aunque se eligiera otro día.
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: "weekly_report", content: content, trigger: trigger)
    }

    private func makeContractExpiryRequest(tenant: Tenant, days: Int, triggerDate: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Contract Renewal", locale: LanguageService.currentLocale, comment: "Notification title for contract expiry")
        content.body = String(localized: "\(tenant.fullName)'s contract expires in \(days) days.", locale: LanguageService.currentLocale, comment: "Notification body for contract expiry")
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: "contract_expiry_\(tenant.id)_\(days)", content: content, trigger: trigger)
    }

    private func makeDepositSummaryRequest(count: Int, date: Date, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Deposit pending", locale: LanguageService.currentLocale, comment: "Notification title for pending deposit reminder")
        content.body = String(localized: "\(count) tenant(s) without a registered deposit", locale: LanguageService.currentLocale, comment: "Notification body counting tenants missing a deposit")
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: "deposit_pending_summary", content: content, trigger: trigger)
    }

    private func makeVacantRoomSummaryRequest(count: Int, date: Date, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Vacant rooms", locale: LanguageService.currentLocale, comment: "Notification title for vacant rooms reminder")
        content.body = String(localized: "\(count) room(s) available to rent", locale: LanguageService.currentLocale, comment: "Notification body counting vacant rooms")
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: "vacant_room_summary", content: content, trigger: trigger)
    }

    private func add(_ request: UNNotificationRequest, to center: UNUserNotificationCenter) async {
        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to add notification \(request.identifier): \(error)")
        }
    }
}
