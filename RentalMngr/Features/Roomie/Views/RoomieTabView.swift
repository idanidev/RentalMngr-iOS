import SwiftUI

enum RoomieSection: String, CaseIterable {
    case rules = "Normas"
    case sharedExpenses = "Gastos"
    case reminders = "Recordatorios"
}

struct RoomieTabView: View {
    @State private var selectedSection: RoomieSection = .rules
    let propertyId: UUID

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sección", selection: $selectedSection) {
                ForEach(RoomieSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedSection {
            case .rules:
                HouseRulesView(propertyId: propertyId)
            case .sharedExpenses:
                SharedExpensesView(propertyId: propertyId)
            case .reminders:
                RemindersView(propertyId: propertyId)
            }
        }
    }
}
