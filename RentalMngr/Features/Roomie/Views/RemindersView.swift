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
                // Skeleton Loading
                List {
                    ForEach(0..<5) { _ in
                        HStack(spacing: 12) {
                            SkeletonView().frame(width: 24, height: 24).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                SkeletonView().frame(width: 150, height: 20)
                                SkeletonView().frame(width: 100, height: 14)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(
            String(localized: "Reminders", locale: LanguageService.currentLocale, comment: "Navigation title for reminders list")
        )
        .onAppear {
            if viewModel == nil {
                viewModel = RemindersViewModel(
                    propertyId: propertyId, reminderService: appState.reminderService)
            }
        }
        .task { await viewModel?.loadReminders() }
    }

    @ViewBuilder
    private func reminderContent(_ vm: RemindersViewModel) -> some View {
        if vm.filteredReminders.isEmpty {
            EmptyStateView(
                icon: "bell.badge",
                title: String(localized: "No reminders", locale: LanguageService.currentLocale, comment: "Empty state title when no reminders exist"),
                subtitle: String(localized: "No pending reminders", locale: LanguageService.currentLocale, comment: "Empty state subtitle for reminders"
                ))
        } else {
            List {
                Toggle(
                    String(localized: "Show completed",
                        locale: LanguageService.currentLocale, comment: "Toggle to show or hide completed reminders"),
                    isOn: Binding(get: { vm.showCompleted }, set: { vm.showCompleted = $0 }))
                ForEach(vm.filteredReminders) { reminder in
                    HStack(spacing: 12) {
                        Button {
                            Task { await vm.toggleCompleted(reminder) }
                        } label: {
                            Image(
                                systemName: reminder.completed ? "checkmark.circle.fill" : "circle"
                            )
                            .foregroundStyle(reminder.completed ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                                .font(.subheadline)
                                .strikethrough(reminder.completed)
                            HStack(spacing: 6) {
                                Text(reminder.reminderType.displayName)
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
                        } label: {
                            Label(
                                String(localized: "Delete",
                                    locale: LanguageService.currentLocale, comment: "Swipe action to delete a reminder"),
                                systemImage: "trash")
                        }
                    }
                }
            }
            .refreshable {
                await vm.refresh()
            }
        }
    }
}
