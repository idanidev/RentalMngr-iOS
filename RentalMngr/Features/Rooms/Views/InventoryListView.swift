import SwiftUI

struct InventoryListView: View {
    let roomId: UUID

    @State private var items: [InventoryItem] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showAddParams = false
    @State private var itemToEdit: InventoryItem?
    @State private var pendingAction: DestructiveAction?
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
                                    pendingAction = DestructiveAction(
                                        title: String(localized: "¿Borrar \(item.name)?", locale: LanguageService.currentLocale, comment: "Delete inventory item title"),
                                        message: String(localized: "Desaparecerá del inventario de la habitación. Si hay una fianza de por medio, es la prueba de lo que había.", locale: LanguageService.currentLocale, comment: "Delete inventory item message"),
                                        confirmLabel: String(localized: "Borrar objeto", locale: LanguageService.currentLocale, comment: "Confirm delete inventory item"),
                                        icon: "shippingbox.fill",
                                        perform: { await deleteItem(item.id) })
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
        .destructiveConfirmation($pendingAction)
        .navigationTitle(String(localized: "Inventory", locale: LanguageService.currentLocale, comment: "Inventory navigation title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddParams = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Añadir artículo", locale: LanguageService.currentLocale, comment: "Accessibility label for add inventory item button"))
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
            errorMsg = error.safeUserMessage
        }
        isLoading = false
    }

    private func deleteItem(_ id: UUID) async {
        do {
            try await service.deleteItem(id: id)
            withAnimation {
                items.removeAll { $0.id == id }
            }
        } catch {
            errorMsg = error.safeUserMessage
        }
    }
}
