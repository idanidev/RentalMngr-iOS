import SwiftUI

struct RoomListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var viewModel: RoomListViewModel?
    @State private var showAddSheet = false
    @State private var roomForAd: Room?
    let propertyId: UUID
    let rooms: [Room]

    /// Single content gutter for the screen (MAC_DESIGN §1): regular 20, compact 16.
    private var gutter: CGFloat { hSize == .regular ? 20 : 16 }

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
                .accessibilityLabel(String(localized: "Añadir habitación", locale: LanguageService.currentLocale, comment: "Accessibility label for add room button"))
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
        .task(id: rooms.map(\.id)) {
            // Firma todas las portadas en UNA petición: si no, cada tarjeta pedía
            // la suya antes de empezar a descargar y la primera carga se arrastraba.
            await SignedURLCache.shared.prefetch(
                bucket: SupabaseConfig.storageBucket,
                paths: rooms.compactMap(\.photos.first))
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
                    Task { await vm.refresh() }
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
                        .padding(.horizontal, gutter)

                        roomGrid {
                            ForEach(vm.privateRooms) { room in
                                NavigationLink(value: room) {
                                    RoomRow(room: room)
                                        .equatable()
                                        .contentShape(Rectangle())
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
                            }
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
                        .padding(.horizontal, gutter)

                        roomGrid {
                            ForEach(vm.commonRooms) { room in
                                NavigationLink(value: room) {
                                    RoomRow(room: room)
                                        .equatable()
                                        .contentShape(Rectangle())
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
                            }
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

    /// Mac/iPad: rooms in an adaptive grid so photos render as proper cards
    /// instead of full-width strips. iPhone: single column (unchanged).
    @ViewBuilder
    private func roomGrid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if hSize == .regular {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 460), spacing: 18, alignment: .top)],
                spacing: 18
            ) {
                content()
            }
            .padding(.horizontal, gutter)
        } else {
            VStack(spacing: 12) {
                content()
            }
            .padding(.horizontal, gutter)
        }
    }
}

private struct RoomRow: View, Equatable {
    @Environment(\.horizontalSizeClass) private var hSize
    let room: Room

    static func == (lhs: RoomRow, rhs: RoomRow) -> Bool {
        lhs.room == rhs.room
    }

    /// Alto del área de imagen.
    ///
    /// Sin foto la tarjeta se encoge **solo en iPhone**, donde las tarjetas van
    /// en columna y el hueco vacío es puro desperdicio. En iPad y Mac van en
    /// rejilla y mantienen el mismo alto: ahí alturas distintas dejan la
    /// cuadrícula dentada (regla de docs/MAC_DESIGN.md).
    private var photoHeight: CGFloat {
        if hSize == .regular { return 210 }
        return room.photos.isEmpty ? 88 : 140
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media (photo or placeholder) with name + price always overlaid,
            // so cards with and without photos line up identically.
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let firstPath = room.photos.first {
                        AsyncImageView(
                            bucket: SupabaseConfig.storageBucket, path: firstPath,
                            contentMode: .fill,
                            // Sin esto se decodificaba la foto entera (hasta 4000 px)
                            // para pintarla en una tarjeta de ~400 pt.
                            targetSize: CGSize(width: 400, height: 300))
                    } else {
                        photoPlaceholder
                    }
                }
                .frame(height: photoHeight)
                .frame(maxWidth: .infinity)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if room.roomType == .privateRoom {
                        Text(room.monthlyRent.formatted(currencyCode: "EUR"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(12)

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
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .macCardHover()

            // Bottom info section
            VStack(alignment: .leading, spacing: 5) {
                if room.roomType == .privateRoom {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(room.occupied ? .blue : .orange)
                        Text(tenantLabel)
                            .font(.subheadline)
                            .foregroundStyle(room.occupied ? Color.primary : Color.orange)
                            .lineLimit(1)
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
                }

                if let size = room.sizeSqm, size > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "ruler")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(NSDecimalNumber(decimal: size).intValue) m²")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 2)
        }
        .padding(.vertical, 4)
    }

    private var tenantLabel: String {
        if let tenant = room.tenantName, !tenant.isEmpty { return tenant }
        return room.occupied ? "Ocupada" : "Libre"
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
                    .font(.title)
                    .foregroundStyle(
                        room.roomType == .common ? .purple.opacity(0.35) : .blue.opacity(0.35))
            }
    }
}
