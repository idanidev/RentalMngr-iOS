import Foundation

enum NotificationFilter: String, CaseIterable {
    case all = "Todas"
    case unread = "No leídas"
    case contracts = "Contratos"
    case weekly = "Semanales"
    case invitations = "Invitaciones"
}

@Observable
final class NotificationViewModel {
    var notifications: [AppNotification] = []
    var localAlerts: [LocalAlert] = []
    var unreadCount = 0
    var isLoading = false
    var errorMessage: String?
    var selectedFilter: NotificationFilter = .all

    private let notificationService: NotificationAppService
    private let localAlertService: LocalAlertService
    private let financeService: FinanceService
    private let systemNotificationService: SystemNotificationService
    private let userId: UUID?

    init(
        notificationService: NotificationAppService, localAlertService: LocalAlertService,
        financeService: FinanceService, systemNotificationService: SystemNotificationService,
        userId: UUID?
    ) {
        self.notificationService = notificationService
        self.localAlertService = localAlertService
        self.financeService = financeService
        self.systemNotificationService = systemNotificationService
        self.userId = userId
    }

    /// Total alert count for badge
    var totalAlertCount: Int {
        unreadCount + localAlerts.count
    }

    /// Filtered notifications based on selected filter
    var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all:
            return notifications
        case .unread:
            return notifications.filter { !$0.read }
        case .contracts:
            return notifications.filter {
                $0.type == .contractExpiring || $0.type == .contractExpired
            }
        case .weekly:
            return notifications.filter { $0.type == .weeklyReport }
        case .invitations:
            return notifications.filter { $0.type == .invitation }
        }
    }

    func loadNotifications() async {
        guard let userId else { return }
        isLoading = true
        do {
            async let fetched = notificationService.fetchNotifications(userId: userId)
            async let count = notificationService.getUnreadCount(userId: userId)
            async let alerts = localAlertService.generateAlerts()
            notifications = try await fetched
            unreadCount = try await count
            localAlerts = await alerts

            // Update system reminders based on unpaid rent alerts
            let unpaidCount = localAlerts.filter { $0.type == .unpaidRent }.count
            systemNotificationService.updatePaymentReminders(pendingCount: unpaidCount)

        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Mark an income entry as paid (from unpaid rent alert)
    func markAlertIncomeAsPaid(_ alert: LocalAlert) async {
        guard let incomeId = alert.relatedIncomeId else { return }
        do {
            try await financeService.markAsPaid(incomeId: incomeId)
            localAlerts.removeAll { $0.id == alert.id }

            // Update system reminders
            let unpaidCount = localAlerts.filter { $0.type == .unpaidRent }.count
            systemNotificationService.updatePaymentReminders(pendingCount: unpaidCount)

        } catch {
            print("[NotificationVM] Error marking paid: \(error)")
        }
    }

    /// Dismiss a local alert (just removes from list, doesn't persist)
    func dismissAlert(_ alert: LocalAlert) {
        localAlerts.removeAll { $0.id == alert.id }
    }

    func markAsRead(_ notification: AppNotification) async {
        do {
            try await notificationService.markAsRead(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].read = true
                unreadCount = max(0, unreadCount - 1)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllAsRead() async {
        guard let userId else { return }
        do {
            try await notificationService.markAllAsRead(userId: userId)
            for i in notifications.indices {
                notifications[i].read = true
            }
            unreadCount = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteNotification(_ notification: AppNotification) async {
        do {
            try await notificationService.deleteNotification(id: notification.id)
            notifications.removeAll { $0.id == notification.id }
            if !notification.read {
                unreadCount = max(0, unreadCount - 1)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
