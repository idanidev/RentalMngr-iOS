import Foundation
import PhotosUI

@MainActor @Observable
final class RoomFormViewModel {
    var name = ""
    var monthlyRent = ""
    var sizeSqm = ""
    var roomType: RoomType = .privateRoom
    var notes = ""
    var isLoading = false
    var errorMessage: String?

    let propertyId: UUID
    let isEditing: Bool
    private let roomService: RoomServiceProtocol
    private var roomId: UUID?
    private(set) var existingPhotos: [String] = []

    func deletePhoto(_ path: String) {
        existingPhotos.removeAll { $0 == path }
    }

    init(
        roomService: RoomServiceProtocol, propertyId: UUID, room: Room? = nil
    ) {
        self.propertyId = propertyId
        self.roomService = roomService
        if let room {
            self.isEditing = true
            self.roomId = room.id
            self.name = room.name
            self.monthlyRent = "\(room.monthlyRent)"
            self.sizeSqm = room.sizeSqm.map { "\($0)" } ?? ""
            self.roomType = room.roomType
            self.notes = room.notes ?? ""
            self.existingPhotos = room.photos
        } else {
            self.isEditing = false
        }
    }

    var isFormValid: Bool {
        let nameOk = !name.trimmingCharacters(in: .whitespaces).isEmpty
        // Common areas don't require a rent value
        let rentOk = roomType == .common || Decimal(string: monthlyRent) != nil
        return nameOk && rentOk
    }

    func save(newPhotos: [Data] = []) async -> Room? {
        // Common areas can have zero/empty rent
        let rent = Decimal(string: monthlyRent) ?? 0
        let size = Decimal(string: sizeSqm)
        isLoading = true
        errorMessage = nil

        do {
            // 1. Initial Room Operation (Create or Update basic info)
            var currentRoom: Room

            if isEditing, let roomId {
                let updated = Room(
                    id: roomId, propertyId: propertyId, tenantId: nil,
                    name: name.trimmingCharacters(in: .whitespaces),
                    monthlyRent: rent, sizeSqm: size,
                    occupied: false, tenantName: nil,
                    notes: notes.isEmpty ? nil : notes,
                    roomType: roomType, photos: existingPhotos,
                    createdAt: nil, updatedAt: nil
                )
                currentRoom = try await roomService.updateRoom(updated)
            } else {
                currentRoom = try await roomService.createRoom(
                    propertyId: propertyId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    monthlyRent: rent,
                    roomType: roomType,
                    sizeSqm: size
                )
            }

            // 2. Upload New Photos
            var uploadedPaths: [String] = []
            if !newPhotos.isEmpty {
                for photoData in newPhotos {
                    let path = "\(currentRoom.id)/\(UUID().uuidString).jpg"
                    let uploadData = ImageCompressor.compress(photoData, maxSizeKB: 800, maxDimension: 1920) ?? photoData
                    try await roomService.uploadPhoto(data: uploadData, path: path)
                    uploadedPaths.append(path)
                }
            }

            // 3. Update Room with new photos if needed
            if !uploadedPaths.isEmpty {
                var allPhotos = currentRoom.photos
                allPhotos.append(contentsOf: uploadedPaths)

                // Create a temporary room object just for the update call
                let roomWithPhotos = Room(
                    id: currentRoom.id,
                    propertyId: currentRoom.propertyId,
                    tenantId: currentRoom.tenantId,
                    name: currentRoom.name,
                    monthlyRent: currentRoom.monthlyRent,
                    sizeSqm: currentRoom.sizeSqm,
                    occupied: currentRoom.occupied,
                    tenantName: currentRoom.tenantName,
                    notes: currentRoom.notes,
                    roomType: currentRoom.roomType,
                    photos: allPhotos,
                    createdAt: currentRoom.createdAt,
                    updatedAt: currentRoom.updatedAt
                )
                currentRoom = try await roomService.updateRoom(roomWithPhotos)
            }

            isLoading = false
            return currentRoom

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
