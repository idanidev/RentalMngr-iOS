import SwiftUI

struct RemindersView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: RemindersViewModel?
    let propertyId: UUID

    var body: some View {
        Group {
            if let vm = viewModel {
                reminderContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Recordatorios")
        .onAppear {
            if viewModel == nil {
                viewModel = RemindersViewModel(propertyId: propertyId, reminderService: appState.reminderService)
            }
        }
        .task { await viewModel?.loadReminders() }
    }

    @ViewBuilder
    private func reminderContent(_ vm: RemindersViewModel) -> some View {
        if vm.filteredReminders.isEmpty {
            EmptyStateView(icon: "bell.badge", title: "Sin recordatorios", subtitle: "No hay recordatorios pendientes")
        } else {
            List {
                Toggle("Mostrar completados", isOn: Binding(get: { vm.showCompleted }, set: { vm.showCompleted = $0 }))
                ForEach(vm.filteredReminders) { reminder in
                    HStack(spacing: 12) {
                        Button {
                            Task { await vm.toggleCompleted(reminder) }
                        } label: {
                            Image(systemName: reminder.completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(reminder.completed ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                                .font(.subheadline)
                                .strikethrough(reminder.completed)
                            HStack(spacing: 6) {
                                Text(reminder.reminderType.rawValue.capitalized)
                                    .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.secondary.opacity(0.2), in: Capsule())
                                Text(reminder.dueDate.shortFormatted)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await vm.deleteReminder(reminder) }
                        } label: { Label("Eliminar", systemImage: "trash") }
                    }
                }
            }
        }
    }
}
