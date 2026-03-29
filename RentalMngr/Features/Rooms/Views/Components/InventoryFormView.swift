import SwiftUI

struct InventoryFormView: View {
    @Environment(\.dismiss) var dismiss

    // Mode: Create or Edit
    var itemToEdit: InventoryItem?
    let roomId: UUID
    var onSave: (InventoryItemOrphan) async throws -> Void
    var onUpdate: (InventoryItem) async throws -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var condition: InventoryCondition = .new
    @State private var purchasePrice: Decimal?
    @State private var purchaseDate: Date = Date()
    @State private var isLoading = false
    @State private var errorMsg: String?

    // For price input
    @State private var priceString: String = ""

    init(
        roomId: UUID, item: InventoryItem? = nil,
        onSave: @escaping (InventoryItemOrphan) async throws -> Void,
        onUpdate: @escaping (InventoryItem) async throws -> Void
    ) {
        self.roomId = roomId
        self.itemToEdit = item
        self.onSave = onSave
        self.onUpdate = onUpdate

        if let item = item {
            _name = State(initialValue: item.name)
            _description = State(initialValue: item.description ?? "")
            _condition = State(initialValue: item.condition)
            _purchaseDate = State(initialValue: item.purchaseDate ?? Date())
            if let price = item.purchasePrice {
                _purchasePrice = State(initialValue: price)
                _priceString = State(initialValue: NSDecimalNumber(decimal: price).stringValue)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text(
                        String(localized: "Basic Info",
                            locale: LanguageService.currentLocale, comment: "Inventory form section header propertys"))
                ) {
                    TextField(
                        String(localized: "Item Name", locale: LanguageService.currentLocale, comment: "Inventory form name placeholder"),
                        text: $name)
                    TextField(
                        String(localized: "Description",
                            locale: LanguageService.currentLocale, comment: "Inventory form description placeholder"), text: $description)
                }

                Section(
                    header: Text(
                        String(localized: "Condition",
                            locale: LanguageService.currentLocale, comment: "Inventory form section header condition"))
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(InventoryCondition.allCases) { cond in
                                ConditionChip(condition: cond, isSelected: condition == cond) {
                                    withAnimation {
                                        condition = cond
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section(
                    header: Text(
                        String(localized: "Purchase Details",
                            locale: LanguageService.currentLocale, comment: "Inventory form section header purchase"))
                ) {
                    TextField(
                        String(localized: "Price", locale: LanguageService.currentLocale, comment: "Inventory form price placeholder"),
                        text: $priceString
                    )
                    .keyboardType(.decimalPad)
                    .onChange(of: priceString) { _, newValue in
                        if let value = Decimal(
                            string: newValue.replacingOccurrences(of: ",", with: "."))
                        {
                            purchasePrice = value
                        }
                    }

                    DatePicker(
                        String(localized: "Purchase Date", locale: LanguageService.currentLocale, comment: "Inventory form date label"),
                        selection: $purchaseDate, displayedComponents: .date)
                }

                if let error = errorMsg {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(
                itemToEdit == nil
                    ? String(localized: "Add Item", locale: LanguageService.currentLocale, comment: "Inventory form add title")
                    : String(localized: "Edit Item", locale: LanguageService.currentLocale, comment: "Inventory form edit title")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Inventory form cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", locale: LanguageService.currentLocale, comment: "Inventory form save")) {
                        save()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    private func save() {
        isLoading = true
        Task {
            do {
                if var item = itemToEdit {
                    // Update
                    item.name = name
                    item.description = description.isEmpty ? nil : description
                    item.condition = condition
                    item.purchasePrice = purchasePrice
                    item.purchaseDate = purchaseDate
                    try await onUpdate(item)
                } else {
                    // Create
                    let newItem = InventoryItemOrphan(
                        roomId: roomId,
                        name: name,
                        description: description.isEmpty ? nil : description,
                        condition: condition,
                        purchaseDate: purchaseDate,
                        purchasePrice: purchasePrice,
                        photos: []
                    )
                    try await onSave(newItem)
                }
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct ConditionChip: View {
    let condition: InventoryCondition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(condition.label)
                .font(.footnote)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? condition.color : condition.color.opacity(0.1))
                .foregroundColor(isSelected ? .white : condition.color)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(condition.color, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
