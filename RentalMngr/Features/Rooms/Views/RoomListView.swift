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
            if let vm = viewModel { Task { await vm.loadRooms() } }
        } content: {
            NavigationStack {
                RoomFormView(propertyId: propertyId, room: nil)
            }
        }
        .sheet(item: $roomForAd) { room in
            NavigationStack {
                RoomAdView(room: room, propertyId: propertyId)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = RoomListViewModel(
                    propertyId: propertyId,
                    roomService: appState.roomService,
                    rooms: rooms
                )
            }
            await viewModel?.loadRooms()
        }
    }

    @ViewBuilder
    private func roomContent(_ vm: RoomListViewModel) -> some View {
        if vm.rooms.isEmpty {
            EmptyStateView(
                icon: "bed.double",
                title: "Sin habitaciones",
                subtitle: "Añade habitaciones a esta propiedad",
                actionTitle: "Añadir habitación"
            ) {
                showAddSheet = true
            }
        } else {
            List {
                if !vm.privateRooms.isEmpty {
                    Section("Privadas (\(vm.privateRooms.count))") {
                        ForEach(vm.privateRooms) { room in
                            NavigationLink(value: room) {
                                RoomRow(room: room)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteRoom(room) }
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    roomForAd = room
                                } label: {
                                    Label("Anuncio PDF", systemImage: "doc.richtext")
                                }
                                .tint(.blue)

                                Button {
                                    Task { await vm.toggleOccupancy(room) }
                                } label: {
                                    Label(
                                        room.occupied ? "Vaciar" : "Ocupar",
                                        systemImage: room.occupied
                                            ? "arrow.uturn.left" : "checkmark")
                                }
                                .tint(room.occupied ? .orange : .green)
                            }
                        }
                    }
                }

                if !vm.commonRooms.isEmpty {
                    Section("Comunes (\(vm.commonRooms.count))") {
                        ForEach(vm.commonRooms) { room in
                            NavigationLink(value: room) {
                                RoomRow(room: room)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteRoom(room) }
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Room.self) { room in
                RoomDetailView(room: room)
            }
        }
    }
}

private struct RoomRow: View {
    let room: Room

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero photo area
            ZStack(alignment: .bottomLeading) {
                if let firstPhotoUrl = room.photoUrls.first {
                    AsyncImage(url: firstPhotoUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            photoPlaceholder
                        default:
                            Rectangle()
                                .fill(.secondary.opacity(0.1))
                                .overlay { ProgressView() }
                        }
                    }
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    photoPlaceholder
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                }

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 70)

                // Room name + rent overlay
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    if room.roomType == .privateRoom {
                        Text(formatCurrency(room.monthlyRent))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(10)

                // Photo count badge
                if room.photos.count > 1 {
                    HStack(spacing: 3) {
                        Image(systemName: "photo.stack")
                            .font(.caption2)
                        Text("\(room.photos.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(8)
                }

                // Occupancy indicator (top-left)
                if room.roomType == .privateRoom {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(room.occupied ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(room.occupied ? "Ocupada" : "Vacante")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

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
    private var photoPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: room.roomType == .common
                        ? [.purple.opacity(0.15), .purple.opacity(0.05)]
                        : [.blue.opacity(0.15), .blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: room.roomType == .common ? "sofa.fill" : "bed.double.fill")
                        .font(.largeTitle)
                        .foregroundStyle(
                            room.roomType == .common ? .purple.opacity(0.4) : .blue.opacity(0.4))
                    Text("Sin fotos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
