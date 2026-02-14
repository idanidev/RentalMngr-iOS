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

    var body: some View {
        List {
            // Photos section
            if !room.photos.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(room.photoUrls, id: \.absoluteString) { url in
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
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
            Section("Información") {
                LabeledContent("Tipo", value: room.roomType == .privateRoom ? "Privada" : "Común")
                if room.roomType == .privateRoom {
                    LabeledContent("Renta mensual", value: formatCurrency(room.monthlyRent))
                }
                if let size = room.sizeSqm {
                    LabeledContent("Tamaño", value: "\(size) m²")
                }
                if room.roomType == .privateRoom {
                    HStack {
                        Text("Estado")
                        Spacer()
                        Text(room.occupied ? "Ocupada" : "Vacante")
                            .fontWeight(.medium)
                            .foregroundStyle(room.occupied ? .green : .orange)
                    }
                }
            }

            // Tenant section - show current tenant or check-in option
            if room.roomType == .privateRoom {
                Section("Inquilino") {
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
                                Text("Check-out")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else if !room.occupied {
                        Button {
                            showCheckInSheet = true
                        } label: {
                            Label("Asignar inquilino (Check-in)", systemImage: "person.badge.plus")
                        }
                    } else {
                        Text("Ocupada sin inquilino asignado")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Notes
            if let notes = room.notes, !notes.isEmpty {
                Section("Notas") {
                    Text(notes)
                        .font(.body)
                }
            }

            // Actions
            Section("Acciones") {
                if room.roomType == .privateRoom {
                    Button {
                        Task {
                            try? await appState.roomService.toggleOccupancy(
                                roomId: room.id, occupied: !room.occupied)
                            await refreshRoom()
                        }
                    } label: {
                        Label(
                            room.occupied ? "Marcar como vacante" : "Marcar como ocupada",
                            systemImage: room.occupied
                                ? "arrow.uturn.left.circle" : "checkmark.circle")
                    }

                    NavigationLink {
                        RoomAdView(room: room, propertyId: room.propertyId)
                    } label: {
                        Label("Generar anuncio PDF", systemImage: "doc.richtext")
                    }
                }

                if room.photos.count > 0 {
                    Button {
                        showPhotos = true
                    } label: {
                        Label(
                            "Ver fotos (\(room.photos.count))",
                            systemImage: "photo.on.rectangle.angled")
                    }
                }
            }
        }
        .navigationTitle(room.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            Task { await refreshRoom() }
        } content: {
            NavigationStack {
                RoomFormView(propertyId: room.propertyId, room: room)
            }
        }
        .sheet(isPresented: $showCheckInSheet) {
            Task { await refreshRoom() }
        } content: {
            NavigationStack {
                RoomCheckInView(room: room, propertyId: room.propertyId)
            }
        }
        .sheet(isPresented: $showPhotos) {
            NavigationStack {
                RoomPhotosView(photos: room.photos)
            }
        }
        .confirmationDialog("¿Hacer check-out?", isPresented: $showCheckOutConfirmation) {
            Button("Confirmar check-out", role: .destructive) {
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
                Text("Se desasignará a \(name) de esta habitación")
            }
        }
        .errorAlert($errorMessage)
    }

    private func refreshRoom() async {
        if let updated = try? await appState.roomService.fetchRoom(id: room.id) {
            room = updated
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: value as NSDecimalNumber) ?? "€0"
    }
}
