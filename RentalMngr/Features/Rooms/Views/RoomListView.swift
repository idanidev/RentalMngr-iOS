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
        HStack(spacing: 12) {
            // Photo thumbnail or status indicator
            if let firstPhotoUrl = room.photoUrls.first {
                AsyncImage(url: firstPhotoUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(room.occupied ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                        .offset(x: 3, y: -3)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.secondary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: room.roomType == .common ? "sofa" : "bed.double")
                        .foregroundStyle(.secondary)
                }
                .overlay(alignment: .topTrailing) {
                    if room.roomType == .privateRoom {
                        Circle()
                            .fill(room.occupied ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                            .offset(x: 3, y: -3)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(room.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    if room.roomType == .privateRoom {
                        Text(formatCurrency(room.monthlyRent))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if room.photos.count > 1 {
                        Label("\(room.photos.count)", systemImage: "photo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if room.roomType == .privateRoom, let tenant = room.tenantName, !tenant.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(tenant)
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }

            Spacer()

            // Occupancy badge (only for private rooms)
            if room.roomType == .privateRoom {
                Text(room.occupied ? "Ocupada" : "Vacante")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        room.occupied ? Color.green.opacity(0.15) : Color.orange.opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(room.occupied ? .green : .orange)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
