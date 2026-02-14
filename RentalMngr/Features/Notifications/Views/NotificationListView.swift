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
        .navigationTitle("Avisos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let vm = viewModel, vm.unreadCount > 0 {
                    Button("Leer todo") {
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
                    propertyService: appState.propertyService
                )
                viewModel = NotificationViewModel(
                    notificationService: appState.notificationService,
                    localAlertService: localAlertService,
                    financeService: appState.financeService,
                    systemNotificationService: appState.systemNotificationService,
                    userId: appState.authService.currentUserId
                )
            }
            // Request permission on first load
            _ = try? await appState.systemNotificationService.requestPermission()

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
                        "Tienes \(vm.unreadCount) notificación\(vm.unreadCount == 1 ? "" : "es") no leída\(vm.unreadCount == 1 ? "" : "s")"
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
                                            Label("Marcar como leído", systemImage: "checkmark")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        Task { await vm.deleteNotification(notification) }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
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
                Text("Alertas activas")
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
                    if alert.type == .unpaidRent {
                        Task { await vm.markAlertIncomeAsPaid(alert) }
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
                            Text(filter.rawValue)
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
        case .all: "Sin avisos"
        case .unread: "Todo leído"
        case .contracts: "Sin alertas de contratos"
        case .weekly: "Sin informes semanales"
        case .invitations: "Sin invitaciones"
        }
    }

    private func emptySubtitle(for filter: NotificationFilter) -> String {
        switch filter {
        case .all: "No tienes notificaciones pendientes"
        case .unread: "Has leído todas las notificaciones"
        case .contracts: "No hay alertas de contratos por vencer"
        case .weekly: "No se han generado informes semanales"
        case .invitations: "No tienes notificaciones de invitaciones"
        }
    }
}

// MARK: - Alert Card

private struct AlertCard: View {
    let alert: LocalAlert
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.icon)
                .font(.title3)
                .foregroundStyle(colorForSeverity(alert.severity))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(alert.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(alert.propertyName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let label = alert.actionLabel {
                Button(label) {
                    onAction()
                }
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(colorForSeverity(alert.severity).opacity(0.15))
                .foregroundStyle(colorForSeverity(alert.severity))
                .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(colorForSeverity(alert.severity).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .swipeActions(edge: .trailing) {
            Button {
                onDismiss()
            } label: {
                Label("Ocultar", systemImage: "eye.slash")
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
