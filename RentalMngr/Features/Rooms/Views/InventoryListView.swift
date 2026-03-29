import SwiftUI

struct InventoryListView: View {
    let roomId: UUID

    @State private var items: [InventoryItem] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showAddParams = false
    @State private var itemToEdit: InventoryItem?
    @Environment(AppState.self) private var appState

    // Service
    let service: InventoryServiceProtocol

    init(roomId: UUID, service: InventoryServiceProtocol, initialItems: [InventoryItem] = []) {
        self.roomId = roomId
        self.service = service
        self._items = State(initialValue: initialItems)
    }

    var body: some View {
        VStack {
            if isLoading && items.isEmpty {
                ProgressView()
                    .padding()
            } else if items.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Items", locale: LanguageService.currentLocale, comment: "Inventory empty title"),
                    systemImage: "cube.box",
                    description: Text(
                        String(localized: "Add furniture and items to this room.",
                            locale: LanguageService.currentLocale, comment: "Inventory empty subtitle"))
                )
            } else {
                List {
                    ForEach(items) { item in
                        InventoryItemRow(item: item)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteItem(item.id)
                                } label: {
                                    Label(
                                        String(localized: "Delete", locale: LanguageService.currentLocale, comment: "Delete action"),
                                        systemImage: "trash")
                                }

                                Button {
                                    itemToEdit = item
                                } label: {
                                    Label(
                                        String(localized: "Edit", locale: LanguageService.currentLocale, comment: "Edit action"),
                                        systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "Inventory", locale: LanguageService.currentLocale, comment: "Inventory navigation title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddParams = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showAddParams) {
            InventoryFormView(
                roomId: roomId,
                onSave: { newItem in
                    let created = try await service.createItem(newItem)
                    withAnimation {
                        items.insert(created, at: 0)
                    }
                },
                onUpdate: { _ in }  // Not used in create mode
            )
            .presentationDetents([.medium, .large])
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(item: $itemToEdit) { item in
            InventoryFormView(
                roomId: roomId,
                item: item,
                onSave: { _ in },
                onUpdate: { updatedItem in
                    let updated = try await service.updateItem(updatedItem)
                    if let index = items.firstIndex(where: { $0.id == updated.id }) {
                        withAnimation {
                            items[index] = updated
                        }
                    }
                }
            )
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .alert(isPresented: .constant(errorMsg != nil)) {
            Alert(
                title: Text(String(localized: "Error", locale: LanguageService.currentLocale, comment: "Alert title")),
                message: Text(errorMsg ?? ""),
                dismissButton: .default(Text(String(localized: "OK", locale: LanguageService.currentLocale, comment: "Alert dismiss button"))) {
                    errorMsg = nil
                }
            )
        }
    }

    private func loadData() async {
        if !items.isEmpty { return }

        isLoading = true
        do {
            items = try await service.fetchInventory(roomId: roomId)
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItem(_ id: UUID) {
        Task {
            do {
                try await service.deleteItem(id: id)
                withAnimation {
                    items.removeAll { $0.id == id }
                }
            } catch {
                errorMsg = error.localizedDescription
            }
        }
    }
}
