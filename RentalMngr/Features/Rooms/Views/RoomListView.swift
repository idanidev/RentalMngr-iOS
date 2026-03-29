import SwiftUI

struct RoomListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: RoomListViewModel?
    @State private var showAddSheet = false
    @State private var roomForAd: Room?
    let propertyId: UUID
    let rooms: [Room]

    var body: some View {
        Group {
            if let vm = viewModel {
                roomContent(vm)
            } else {
                LoadingView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let vm = viewModel { Task { await vm.refresh() } }
        } content: {
            NavigationStack {
                RoomFormView(propertyId: propertyId, room: nil)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .sheet(item: $roomForAd) { room in
            NavigationStack {
                RoomAdView(room: room, propertyId: propertyId)
            }
            .preferredColorScheme(appState.userInterfaceStyle.colorScheme)
        }
        .task {
            if viewModel == nil {
                viewModel = RoomListViewModel(
                    propertyId: propertyId,
                    roomService: appState.roomService,
                    tenantService: appState.tenantService,
                    rooms: rooms
                )
            }
        }
        .onChange(of: rooms) { _, newRooms in
            viewModel?.rooms = newRooms
        }
    }

    @ViewBuilder
    private func roomContent(_ vm: RoomListViewModel) -> some View {
        if vm.isLoading {
            LoadingView()
        } else if let error = vm.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Error loading rooms", comment: "Error heading when rooms fail to load")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(String(localized: "Retry", locale: LanguageService.currentLocale, comment: "Retry loading button")) {
                    Task { await vm.loadRooms() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else if vm.rooms.isEmpty {
            EmptyStateView(
                icon: "bed.double",
                title: String(localized: "No rooms", locale: LanguageService.currentLocale, comment: "Empty state title when no rooms exist"),
                subtitle: String(localized: "Add rooms to this property",
                    locale: LanguageService.currentLocale, comment: "Empty state subtitle for rooms"),
                actionTitle: String(localized: "Add room", locale: LanguageService.currentLocale, comment: "Button to add a new room")
            ) {
                showAddSheet = true
            }
        } else {
            VStack(spacing: 24) {
                if !vm.privateRooms.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            "Private (\(vm.privateRooms.count))",
                            comment: "Section header for private rooms with count"
                        )
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                        ForEach(vm.privateRooms) { room in
                            NavigationLink(value: room) {
                                RoomRow(room: room)
                                    .equatable()
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    roomForAd = room
                                } label: {
                                    Label(
                                        String(localized: "PDF Ad",
                                            locale: LanguageService.currentLocale, comment: "Context menu action to generate PDF ad"),
                                        systemImage: "doc.richtext")
                                }

                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    Task { await vm.toggleOccupancy(room) }
                                } label: {
                                    Label(
                                        room.occupied
                                            ? String(localized: "Mark as Vacant",
                                                locale: LanguageService.currentLocale, comment:
                                                    "Context menu action to mark room as vacant")
                                            : String(localized: "Mark as Occupied",
                                                locale: LanguageService.currentLocale, comment:
                                                    "Context menu action to mark room as occupied"),
                                        systemImage: room.occupied
                                            ? "arrow.uturn.left" : "checkmark"
                                    )
                                }

                                Button(role: .destructive) {
                                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                    Task { await vm.deleteRoom(room) }
                                } label: {
                                    Label(
                                        String(localized: "Delete",
                                            locale: LanguageService.currentLocale, comment: "Context menu action to delete"),
                                        systemImage: "trash")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                if !vm.commonRooms.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            "Common (\(vm.commonRooms.count))",
                            comment: "Section header for common rooms with count"
                        )
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                        ForEach(vm.commonRooms) { room in
                            NavigationLink(value: room) {
                                RoomRow(room: room)
                                    .equatable()
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await vm.deleteRoom(room) }
                                } label: {
                                    Label(
                                        String(localized: "Delete",
                                            locale: LanguageService.currentLocale, comment: "Context menu action to delete"),
                                        systemImage: "trash")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
            .refreshable {
                await vm.refresh()
            }
        }
    }
}

private struct RoomRow: View, Equatable {
    let room: Room

    static func == (lhs: RoomRow, rhs: RoomRow) -> Bool {
        lhs.room == rhs.room
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero photo area
            if let firstPhotoUrl = room.listThumbnailUrls.first {
                // ── CON FOTO: texto blanco sobre gradiente oscuro ──
                ZStack(alignment: .bottomLeading) {
                    AsyncImageView(url: firstPhotoUrl, contentMode: .fill)
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(room.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        if room.roomType == .privateRoom {
                            Text(room.monthlyRent.formatted(currencyCode: "EUR"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(10)

                    if room.photos.count > 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "photo.stack").font(.caption2)
                            Text("\(room.photos.count)").font(.caption2.bold())
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(8)
                    }

                    if room.roomType == .privateRoom {
                        occupancyBadge
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                // ── SIN FOTO: placeholder + texto legible en cualquier modo ──
                ZStack(alignment: .topLeading) {
                    photoPlaceholder
                        .frame(height: 88)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if room.roomType == .privateRoom {
                        occupancyBadge.padding(8)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(room.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        if room.roomType == .privateRoom {
                            Text(room.monthlyRent.formatted(currencyCode: "EUR"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.horizontal, 2)
            }

            // Bottom info section
            if room.roomType == .privateRoom {
                if let tenant = room.tenantName, !tenant.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text(tenant)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 2)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "sofa.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("Zona común")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var occupancyBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(room.occupied ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(room.occupied ? "Ocupada" : "Libre")
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    @ViewBuilder
    private var photoPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: room.roomType == .common
                        ? [.purple.opacity(0.12), .purple.opacity(0.04)]
                        : [.blue.opacity(0.12), .blue.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: room.roomType == .common ? "sofa.fill" : "bed.double.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        room.roomType == .common ? .purple.opacity(0.35) : .blue.opacity(0.35))
            }
    }
}
