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

        // Server-backed settings (contract + weekly report) when a user is signed in.
        var serverSettings: NotificationSettings?
        if let userId {
            serverSettings = try? await notificationService.fetchOrCreateSettings(userId: userId)
        }

        var repeating: [UNNotificationRequest] = []
        var oneShots: [(date: Date, request: UNNotificationRequest)] = []

        // 1. Monthly rent reminder (repeating) — local toggle.
        if defaults.bool(forKey: LocalNotifPrefKey.rentReminder) {
            repeating.append(makeRentReminderRequest())
        }

        // 2. Weekly report (repeating) — server toggle.
        if serverSettings?.enableWeeklyReport == true {
            let weekday = defaults.object(forKey: LocalNotifPrefKey.weeklyReportWeekday) as? Int ?? 2
            repeating.append(makeWeeklyReportRequest(weekday: weekday))
        }

        // Scan data once: tenants + rooms per property.
        let properties = (try? await propertyService.fetchProperties()) ?? []
        let contractAlertsEnabled = serverSettings?.enableContractAlerts ?? true
        let alertDays = serverSettings?.contractAlertDays ?? [30, 15, 7]
        let depositEnabled = defaults.bool(forKey: LocalNotifPrefKey.depositPending)
        let vacantEnabled = defaults.bool(forKey: LocalNotifPrefKey.vacantRoom)

        var depositPendingCount = 0
        var vacantRoomCount = 0

        // Una sola consulta para todas las propiedades: antes era una por cada
        // una, y esto corre en CADA vuelta a primer plano.
        let tenantsByProperty = Dictionary(
            grouping: (try? await tenantService.fetchActiveTenants(
                propertyIds: properties.map(\.id))) ?? [],
            by: \.propertyId)

        for property in properties {
            let tenants = tenantsByProperty[property.id] ?? []
            // Rooms (with `occupied`) are already embedded by fetchProperties — no extra fetch.
            let rooms = property.rooms ?? []

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
                if depositEnabled, hasContract(tenant), isDepositMissing(tenant) {
                    depositPendingCount += 1
                }
            }

            if vacantEnabled {
                vacantRoomCount += rooms.filter { !$0.occupied }.count
            }
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

    private func makeWeeklyReportRequest(weekday: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Weekly summary", locale: LanguageService.currentLocale, comment: "Toggle title for weekly report notification")
        content.body = String(localized: "Occupancy, income and outstanding payments — every Monday at 9:00 AM", locale: LanguageService.currentLocale, comment: "Subtitle describing weekly report schedule and content")
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
