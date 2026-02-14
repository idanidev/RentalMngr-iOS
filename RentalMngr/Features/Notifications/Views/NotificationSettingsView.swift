import SwiftUI

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var settings: NotificationSettings?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showTestSuccess = false
    @State private var isSendingTest = false

    private let alertDayOptions = [7, 15, 30, 60]

    var body: some View {
        Form {
            if let settings = Binding($settings) {
                // Contract alerts
                Section {
                    Toggle(isOn: settings.enableContractAlerts) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Alertas de contratos")
                                Text("Recibe avisos antes de que venzan los contratos")
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
                            Text("Avisar con antelación de:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                ForEach(alertDayOptions, id: \.self) { days in
                                    let isSelected = settings.wrappedValue.contractAlertDays.contains(days)
                                    Button {
                                        toggleAlertDay(days)
                                    } label: {
                                        Text("\(days) días")
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
                    Text("Contratos")
                }

                // Weekly report
                Section {
                    Toggle(isOn: settings.enableWeeklyReport) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Informe semanal")
                                Text("Cada lunes a las 9:00")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("Informes")
                }

                // Other notifications
                Section {
                    Toggle(isOn: settings.enableInvitationAlerts) {
                        Label {
                            Text("Invitaciones")
                        } icon: {
                            Image(systemName: "person.badge.plus")
                                .foregroundStyle(.green)
                        }
                    }

                    Toggle(isOn: settings.enableExpenseAlerts) {
                        Label {
                            Text("Nuevos gastos")
                        } icon: {
                            Image(systemName: "eurosign.circle")
                                .foregroundStyle(.orange)
                        }
                    }

                    Toggle(isOn: settings.enableIncomeAlerts) {
                        Label {
                            Text("Nuevos ingresos")
                        } icon: {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.green)
                        }
                    }

                    Toggle(isOn: settings.enableRoomAlerts) {
                        Label {
                            Text("Cambios de habitación")
                        } icon: {
                            Image(systemName: "bed.double")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("Otras notificaciones")
                }

                // Test notification
                Section {
                    Button {
                        Task { await sendTestNotification() }
                    } label: {
                        HStack {
                            Label {
                                Text("Crear notificación de prueba")
                            } icon: {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.yellow)
                            }
                            Spacer()
                            if isSendingTest {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isSendingTest)
                } header: {
                    Text("Pruebas")
                } footer: {
                    Text("Envía una notificación de prueba para comprobar que todo funciona correctamente.")
                }

            } else if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Cargando ajustes...")
                        Spacer()
                    }
                }
            }

            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle("Ajustes de avisos")
        .task {
            await loadSettings()
        }
        .onChange(of: settings) { _, newValue in
            guard let newValue else { return }
            Task {
                try? await appState.notificationService.updateSettings(newValue)
            }
        }
        .alert("Notificación enviada", isPresented: $showTestSuccess) {
            Button("OK") { }
        } message: {
            Text("Se ha creado una notificación de prueba. Revisa la pestaña de Avisos.")
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

    private func sendTestNotification() async {
        guard let userId = appState.authService.currentUserId else { return }
        isSendingTest = true
        do {
            try await appState.notificationService.createTestNotification(userId: userId, propertyId: nil)
            showTestSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSendingTest = false
    }
}
