import SwiftUI

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var settings: NotificationSettings?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @AppStorage("weeklyReportWeekday") private var weeklyReportWeekday: Int = 2  // Monday

    private let alertDayOptions = [7, 15, 30, 60]
    // UNCalendarNotificationTrigger: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    // Display Mon→Sun using system locale's short weekday symbols
    private let weekdays: [(Int, String)] = {
        let symbols = Calendar.current.shortWeekdaySymbols  // index 0=Sun, 1=Mon, ...
        let order = [2, 3, 4, 5, 6, 7, 1]  // Mon first, Sun last
        return order.map { weekday in (weekday, symbols[weekday - 1]) }
    }()

    var body: some View {
        Form {
            if let settings = Binding($settings) {
                // MARK: - Contracts
                Section {
                    Toggle(isOn: settings.enableContractAlerts) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Contract expiry", locale: LanguageService.currentLocale, comment: "Toggle title for contract expiry alerts"))
                                    .font(.body)
                                Text(String(localized: "Alerts when a tenant's contract is about to expire or has already expired", locale: LanguageService.currentLocale, comment: "Subtitle for contract alerts toggle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.badge.clock")
                                .foregroundStyle(.orange)
                        }
                    }

                    if settings.wrappedValue.enableContractAlerts {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Notify in advance:", locale: LanguageService.currentLocale, comment: "Label for contract alert days selection"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                ForEach(alertDayOptions, id: \.self) { days in
                                    let isSelected = settings.wrappedValue.contractAlertDays.contains(days)
                                    Button {
                                        toggleAlertDay(days)
                                    } label: {
                                        Text(
                                            days == 1
                                                ? String(localized: "1 day", locale: LanguageService.currentLocale, comment: "1 day advance notice option")
                                                : String(localized: "\(days) days", locale: LanguageService.currentLocale, comment: "Number of days for contract alert advance notice")
                                        )
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.1))
                                        .foregroundStyle(isSelected ? .orange : .secondary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(String(localized: "Contracts", locale: LanguageService.currentLocale, comment: "Section header for contract alert settings"))
                } footer: {
                    Text(String(localized: "You will also receive an alert when a contract has already expired.", locale: LanguageService.currentLocale, comment: "Footer explaining expired contract alerts"))
                }

                // MARK: - Financial
                Section {
                    Toggle(isOn: settings.enableIncomeAlerts) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Rent payments", locale: LanguageService.currentLocale, comment: "Toggle title for income alerts"))
                                    .font(.body)
                                Text(String(localized: "When a payment is marked as paid or a new income entry is added", locale: LanguageService.currentLocale, comment: "Subtitle for income alerts toggle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.green)
                        }
                    }

                    Toggle(isOn: settings.enableExpenseAlerts) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Expenses", locale: LanguageService.currentLocale, comment: "Toggle title for expense alerts"))
                                    .font(.body)
                                Text(String(localized: "When a new expense is logged on any of your properties", locale: LanguageService.currentLocale, comment: "Subtitle for expense alerts toggle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.up.circle")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text(String(localized: "Finances", locale: LanguageService.currentLocale, comment: "Section header for financial notification settings"))
                }

                // MARK: - Property
                Section {
                    Toggle(isOn: settings.enableRoomAlerts) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Room changes", locale: LanguageService.currentLocale, comment: "Toggle title for room change alerts"))
                                    .font(.body)
                                Text(String(localized: "When a room is occupied, vacated or its details are updated", locale: LanguageService.currentLocale, comment: "Subtitle for room change alerts toggle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "bed.double")
                                .foregroundStyle(.cyan)
                        }
                    }

                    Toggle(isOn: settings.enableInvitationAlerts) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Invitations", locale: LanguageService.currentLocale, comment: "Toggle label for invitation alerts"))
                                    .font(.body)
                                Text(String(localized: "When someone accepts or rejects an invitation to a property", locale: LanguageService.currentLocale, comment: "Subtitle for invitation alerts toggle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.badge.plus")
                                .foregroundStyle(.purple)
                        }
                    }
                } header: {
                    Text(String(localized: "Properties", locale: LanguageService.currentLocale, comment: "Section header for property notification settings"))
                }

                // MARK: - Reports
                Section {
                    Toggle(isOn: settings.enableWeeklyReport) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Weekly summary", locale: LanguageService.currentLocale, comment: "Toggle title for weekly report notification"))
                                    .font(.body)
                                Text(String(localized: "Occupancy, income and outstanding payments — every Monday at 9:00 AM", locale: LanguageService.currentLocale, comment: "Subtitle describing weekly report schedule and content"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundStyle(.blue)
                        }
                    }

                    if settings.wrappedValue.enableWeeklyReport {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Day of week:", locale: LanguageService.currentLocale, comment: "Label for weekly report day selector"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 6) {
                                ForEach(weekdays, id: \.0) { weekday, label in
                                    let isSelected = weeklyReportWeekday == weekday
                                    Button {
                                        weeklyReportWeekday = weekday
                                    } label: {
                                        Text(label)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .frame(minWidth: 36)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(isSelected ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
                                            .foregroundStyle(isSelected ? .blue : .secondary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(String(localized: "Reports", locale: LanguageService.currentLocale, comment: "Section header for report notification settings"))
                }

            } else if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView(String(localized: "Loading settings...", locale: LanguageService.currentLocale, comment: "Loading indicator for notification settings"))
                        Spacer()
                    }
                }
            }

            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle(String(localized: "Notification settings", locale: LanguageService.currentLocale, comment: "Navigation title for notification settings screen"))
        .task {
            await loadSettings()
        }
        .onChange(of: settings) { _, newValue in
            guard let newValue else { return }
            Task {
                try? await appState.notificationService.updateSettings(newValue)
            }
        }
        .onChange(of: settings?.enableWeeklyReport) { _, enabled in
            Task {
                if enabled == true {
                    await appState.notificationService.scheduleWeeklyReport(weekday: weeklyReportWeekday)
                } else {
                    appState.notificationService.cancelWeeklyReport()
                }
            }
        }
        .onChange(of: weeklyReportWeekday) { _, newWeekday in
            guard settings?.enableWeeklyReport == true else { return }
            Task {
                await appState.notificationService.scheduleWeeklyReport(weekday: newWeekday)
            }
        }
    }

    private func loadSettings() async {
        guard let userId = appState.authService.currentUserId else { return }
        do {
            settings = try await appState.notificationService.fetchOrCreateSettings(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleAlertDay(_ day: Int) {
        guard var current = settings else { return }
        if current.contractAlertDays.contains(day) {
            current.contractAlertDays.removeAll { $0 == day }
        } else {
            current.contractAlertDays.append(day)
            current.contractAlertDays.sort()
        }
        settings = current
    }
}
