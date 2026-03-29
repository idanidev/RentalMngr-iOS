import SwiftUI

struct RoomDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var room: Room
    @State private var showEditSheet = false
    @State private var showPhotos = false
    @State private var showCheckInSheet = false
    @State private var showCheckOutConfirmation = false
    @State private var errorMessage: String?

    init(room: Room) {
        _room = State(initialValue: room)
    }

    @State private var inventory: [InventoryItem] = []

    var body: some View {
        List {
            // Photos section
            if !room.photos.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(room.stripThumbnailUrls, id: \.absoluteString) { url in
                                AsyncImageView(url: url, contentMode: .fill, targetSize: CGSize(width: 120, height: 90))
                                    .frame(width: 120, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture { showPhotos = true }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Info
            Section(String(localized: "Information", locale: LanguageService.currentLocale, comment: "Section header for room info")) {
                LabeledContent(
                    String(localized: "Type", locale: LanguageService.currentLocale, comment: "Room type label"),
                    value: room.roomType == .privateRoom
                        ? String(localized: "Private", locale: LanguageService.currentLocale, comment: "Private room type")
                        : String(localized: "Common", locale: LanguageService.currentLocale, comment: "Common room type"))
                if room.roomType == .privateRoom {
                    LabeledContent(
                        String(localized: "Monthly rent", locale: LanguageService.currentLocale, comment: "Monthly rent label"),
                        value: room.monthlyRent.formatted(currencyCode: "EUR"))
                }
                if let size = room.sizeSqm {
                    LabeledContent(
                        String(localized: "Size", locale: LanguageService.currentLocale, comment: "Room size label"), value: "\(size) m²")
                }
                if room.roomType == .privateRoom {
                    HStack {
                        Text(String(localized: "Status", locale: LanguageService.currentLocale, comment: "Room occupancy status label"))
                        Spacer()
                        Text(
                            room.occupied
                                ? String(localized: "Occupied", locale: LanguageService.currentLocale, comment: "Room is occupied")
                                : String(localized: "Vacant", locale: LanguageService.currentLocale, comment: "Room is vacant")
                        )
                        .fontWeight(.medium)
                        .foregroundStyle(room.occupied ? .green : .orange)
                    }
                }
            }

            // Tenant section - show current tenant or check-in option
            if room.roomType == .privateRoom {
                Section(String(localized: "Tenant", locale: LanguageService.currentLocale, comment: "Section header for tenant info")) {
                    if let tenantName = room.tenantName, !tenantName.isEmpty, room.occupied {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(tenantName, systemImage: "person.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                showCheckOutConfirmation = true
                            } label: {
                                Text(String(localized: "Check-out", locale: LanguageService.currentLocale, comment: "Check-out button label"))
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else if !room.occupied {
                        Button {
                            showCheckInSheet = true
                        } label: {
                            Label(
                                String(localized: "Assign tenant (Check-in)",
                                    locale: LanguageService.currentLocale, comment: "Button to assign a tenant to a room"),
                                systemImage: "person.badge.plus")
                        }
                    } else {
                        Text(String(localized: "Occupied without assigned tenant", locale: LanguageService.currentLocale, comment: "Status when room is occupied but no tenant assigned"))
                        .foregroundStyle(.secondary)
                    }
                }
            }

            // Notes
            if let notes = room.notes, !notes.isEmpty {
                Section(String(localized: "Notes", locale: LanguageService.currentLocale, comment: "Section header for notes")) {
                    Text(notes)
                        .font(.body)
                }
            }

            // Inventory
            Section(String(localized: "Inventory", locale: LanguageService.currentLocale, comment: "Section header for inventory")) {
                NavigationLink {
                    InventoryListView(
                        roomId: room.id,
                        service: appState.inventoryService,
                        initialItems: inventory
                    )
                    .navigationTitle(
                        String(localized: "Inventory of \(room.name)",
                            locale: LanguageService.currentLocale, comment: "Navigation title for room inventory"))
                } label: {
                    Label(
                        String(localized: "View inventory", locale: LanguageService.currentLocale, comment: "Button to view room inventory"),
                        systemImage: "square.grid.2x2")
                }
            }

            // Actions
            Section(String(localized: "Actions", locale: LanguageService.currentLocale, comment: "Section header for actions")) {
                if room.roomType == .privateRoom {
                    Button {
                        Task {
                            do {
                                try await appState.roomService.toggleOccupancy(
                                    roomId: room.id, occupied: !room.occupied)
                                await refreshRoom()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Label(
                            room.occupied
                                ? String(localized: "Mark as vacant",
                                    locale: LanguageService.currentLocale, comment: "Action to mark room as vacant")
                                : String(localized: "Mark as occupied",
                                    locale: LanguageService.currentLocale, comment: "Action to mark room as occupied"),
                            systemImage: room.occupied
                                ? "arrow.uturn.left.circle" : "checkmark.circle")
                    }

                    NavigationLink {
                        RoomAdView(room: room, propertyId: room.propertyId)
                    } label: {
                        Label(
                            String(localized: "Generate PDF ad",
                                locale: LanguageService.currentLocale, comment: "Action to generate a PDF listing ad"),
                            systemImage: "doc.richtext")
                    }
                }

                if room.photos.count > 0 {
                    Button {
                        showPhotos = true
                    } label: {
                        Label(
                            String(localized: "View photos (\(room.photos.count))",
                                locale: LanguageService.currentLocale, comment: "Action to view room photos with count"),
                            systemImage: "photo.on.rectangle.angled")
                    }
                }
            }
        }
        .navigationTitle(room.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit", locale: LanguageService.currentLocale, comment: "Button to edit room")) {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            Task { await refreshRoom() }
        } content: {
            NavigationStack {
                RoomFormView(propertyId: room.propertyId, room: room)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showCheckInSheet) {
            Task { await refreshRoom() }
        } content: {
            NavigationStack {
                RoomCheckInView(room: room, propertyId: room.propertyId)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(isPresented: $showPhotos) {
            NavigationStack {
                RoomPhotosView(photos: room.photos)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .confirmationDialog(
            String(localized: "Check out?", locale: LanguageService.currentLocale, comment: "Confirmation dialog title for check-out"),
            isPresented: $showCheckOutConfirmation
        ) {
            Button(
                String(localized: "Confirm check-out", locale: LanguageService.currentLocale, comment: "Button to confirm tenant check-out"),
                role: .destructive
            ) {
                Task {
                    do {
                        try await appState.tenantService.unassignFromRoom(roomId: room.id)
                        await refreshRoom()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            if let name = room.tenantName {
                Text(String(localized: "\(name) will be unassigned from this room", locale: LanguageService.currentLocale, comment: "Check-out confirmation message with tenant name"))
            }
        }
        .errorAlert($errorMessage)
    }

    private func refreshRoom() async {
        let roomId = room.id
        let propertyId = room.propertyId

        await withTaskGroup(of: Void.self) { group in
            // 1. Fetch Room Details
            group.addTask {
                guard let updated = try? await appState.roomService.fetchRoom(id: roomId) else {
                    return
                }
                var roomWithTenant = updated

                // Fetch active tenant if room is occupied but tenant not linked
                if roomWithTenant.occupied {
                    if let activeTenants = try? await appState.tenantService.fetchActiveTenants(
                        propertyId: propertyId),
                        let tenant = activeTenants.first(where: { $0.room?.id == roomWithTenant.id }
                        )
                    {
                        roomWithTenant.tenantName = tenant.fullName
                        roomWithTenant.tenantId = tenant.id
                    }
                }

                let finalRoom = roomWithTenant
                await MainActor.run {
                    self.room = finalRoom
                }
            }

            // 2. Prefetch Inventory
            group.addTask {
                if let items = try? await appState.inventoryService.fetchInventory(roomId: roomId) {
                    await MainActor.run {
                        self.inventory = items
                    }
                }
            }
        }
    }

}
