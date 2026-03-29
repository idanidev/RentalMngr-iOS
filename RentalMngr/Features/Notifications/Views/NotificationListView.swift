import SwiftUI

struct NotificationListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: NotificationViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                notificationContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(String(localized: "Notifications", locale: LanguageService.currentLocale, comment: "Navigation title for notifications list"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let vm = viewModel, vm.unreadCount > 0 {
                    Button(String(localized: "Read all", locale: LanguageService.currentLocale, comment: "Button to mark all notifications as read")) {
                        Task { await vm.markAllAsRead() }
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                let localAlertService = LocalAlertService(
                    tenantService: appState.tenantService,
                    financeService: appState.financeService,
                    propertyService: appState.propertyService,
                    utilityService: appState.utilityService
                )
                viewModel = NotificationViewModel(
                    notificationService: appState.notificationService,
                    localAlertService: localAlertService,
                    financeService: appState.financeService,
                    utilityService: appState.utilityService,
                    systemNotificationService: appState.systemNotificationService,
                    userId: appState.authService.currentUserId
                )
            }
            // Request permission on first load
            _ = try? await appState.systemNotificationService?.requestPermission()

            await viewModel?.loadNotifications()
        }
    }

    @ViewBuilder
    private func notificationContent(_ vm: NotificationViewModel) -> some View {
        VStack(spacing: 0) {
            // Filter bar (matches webapp dropdown filter)
            filterBar(vm)

            // Unread count banner
            if vm.unreadCount > 0 && vm.selectedFilter == .all {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.blue)
                    Text(
                        "You have \(vm.unreadCount) unread notification\(vm.unreadCount == 1 ? "" : "s")",
                        comment: "Banner showing number of unread notifications"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.05))
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    // MARK: - Local Alerts Section
                    if !vm.localAlerts.isEmpty && vm.selectedFilter == .all {
                        localAlertsSection(vm)
                    }

                    if let error = vm.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundStyle(.orange)
                            Text("Error loading notifications", comment: "Error title when notifications fail to load")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(String(localized: "Retry", locale: LanguageService.currentLocale, comment: "Button to retry loading notifications")) {
                                Task { await vm.loadNotifications() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 40)
                    }

                    // MARK: - Notifications
                    if vm.filteredNotifications.isEmpty && vm.localAlerts.isEmpty && !vm.isLoading {
                        EmptyStateView(
                            icon: vm.selectedFilter == .unread ? "bell.badge.slash" : "bell.slash",
                            title: emptyTitle(for: vm.selectedFilter),
                            subtitle: emptySubtitle(for: vm.selectedFilter)
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(vm.filteredNotifications) { notification in
                            NotificationRow(notification: notification)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .contextMenu {
                                    if !notification.read {
                                        Button {
                                            Task { await vm.markAsRead(notification) }
                                        } label: {
                                            Label(String(localized: "Mark as read", locale: LanguageService.currentLocale, comment: "Context menu action to mark notification as read"), systemImage: "checkmark")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        Task { await vm.deleteNotification(notification) }
                                    } label: {
                                        Label(String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Context menu action to delete notification"), systemImage: "trash")
                                    }
                                }

                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .refreshable {
                await vm.loadNotifications()
            }
        }
    }

    // MARK: - Local Alerts Section

    @ViewBuilder
    private func localAlertsSection(_ vm: NotificationViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Active alerts", comment: "Section header for active local alerts")
                    .font(.headline)
                Spacer()
                Text("\(vm.localAlerts.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ForEach(vm.localAlerts) { alert in
                AlertCard(alert: alert) {
                    // Action button tapped
                    switch alert.type {
                    case .unpaidRent:
                        Task { await vm.markAlertIncomeAsPaid(alert) }
                    case .unpaidUtility:
                        Task { await vm.markAlertUtilityAsPaid(alert) }
                    default:
                        break
                    }
                } onDismiss: {
                    vm.dismissAlert(alert)
                }
            }
            .padding(.horizontal, 12)

            Divider()
                .padding(.vertical, 8)
        }
    }

    // MARK: - Filter Bar

    @ViewBuilder
    private func filterBar(_ vm: NotificationViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NotificationFilter.allCases, id: \.self) { filter in
                    let isSelected = vm.selectedFilter == filter
                    Button {
                        vm.selectedFilter = filter
                    } label: {
                        HStack(spacing: 4) {
                            Text(filter.displayName)
                                .font(.caption)
                                .fontWeight(isSelected ? .semibold : .regular)
                            if filter == .all {
                                Text("\(vm.notifications.count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.secondary.opacity(0.2))
                                    .clipShape(Capsule())
                            } else if filter == .unread && vm.unreadCount > 0 {
                                Text("\(vm.unreadCount)")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.blue.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isSelected
                                ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)
                        )
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func emptyTitle(for filter: NotificationFilter) -> String {
        switch filter {
        case .all: String(localized: "No notifications", locale: LanguageService.currentLocale, comment: "Empty state title when no notifications exist")
        case .unread: String(localized: "All read", locale: LanguageService.currentLocale, comment: "Empty state title when all notifications are read")
        case .contracts: String(localized: "No contract alerts", locale: LanguageService.currentLocale, comment: "Empty state title for contract filter")
        case .weekly: String(localized: "No weekly reports", locale: LanguageService.currentLocale, comment: "Empty state title for weekly report filter")
        case .invitations: String(localized: "No invitations", locale: LanguageService.currentLocale, comment: "Empty state title for invitations filter")
        }
    }

    private func emptySubtitle(for filter: NotificationFilter) -> String {
        switch filter {
        case .all: String(localized: "You have no pending notifications", locale: LanguageService.currentLocale, comment: "Empty state subtitle when no notifications exist")
        case .unread: String(localized: "You have read all notifications", locale: LanguageService.currentLocale, comment: "Empty state subtitle when all are read")
        case .contracts: String(localized: "No upcoming contract expiry alerts", locale: LanguageService.currentLocale, comment: "Empty state subtitle for contract filter")
        case .weekly: String(localized: "No weekly reports have been generated", locale: LanguageService.currentLocale, comment: "Empty state subtitle for weekly report filter")
        case .invitations: String(localized: "You have no invitation notifications", locale: LanguageService.currentLocale, comment: "Empty state subtitle for invitations filter")
        }
    }
}

// MARK: - Alert Card

private struct AlertCard: View {
    let alert: LocalAlert
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: alert.icon)
                .font(.subheadline)
                .foregroundStyle(colorForSeverity(alert.severity))
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(alert.propertyName) · \(alert.message)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let label = alert.actionLabel {
                    Button(label) {
                        onAction()
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(colorForSeverity(alert.severity).opacity(0.15))
                    .foregroundStyle(colorForSeverity(alert.severity))
                    .clipShape(Capsule())
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(colorForSeverity(alert.severity).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .swipeActions(edge: .trailing) {
            Button {
                onDismiss()
            } label: {
                Label(String(localized: "Hide", locale: LanguageService.currentLocale, comment: "Swipe action to dismiss an alert"), systemImage: "eye.slash")
            }
            .tint(.gray)
        }
    }

    private func colorForSeverity(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .info: .blue
        case .warning: .orange
        case .critical: .red
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(notification.type))
                .foregroundStyle(colorForType(notification.type))
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(notification.read ? .regular : .bold)
                    Spacer()
                    Text(notification.createdAt.relativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(notification.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !notification.read {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 2)
        .opacity(notification.read ? 0.7 : 1.0)
    }

    private func iconForType(_ type: NotificationType) -> String {
        switch type {
        case .contractExpiring: "doc.badge.clock"
        case .contractExpired: "doc.badge.ellipsis"
        case .weeklyReport: "chart.bar.doc.horizontal"
        case .invitation: "person.badge.plus"
        case .expense: "arrow.up.circle"
        case .income: "arrow.down.circle"
        case .roomChange: "bed.double"
        }
    }

    private func colorForType(_ type: NotificationType) -> Color {
        switch type {
        case .contractExpiring: .orange
        case .contractExpired: .red
        case .weeklyReport: .blue
        case .invitation: .purple
        case .expense: .red
        case .income: .green
        case .roomChange: .cyan
        }
    }
}
