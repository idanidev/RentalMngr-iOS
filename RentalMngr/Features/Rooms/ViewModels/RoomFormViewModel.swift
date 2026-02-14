import Foundation
import PhotosUI

@Observable
final class RoomFormViewModel {
    var name = ""
    var monthlyRent = ""
    var sizeSqm = ""
    var roomType: RoomType = .privateRoom
    var notes = ""
    var isLoading = false
    var errorMessage: String?

    let isEditing: Bool
    let propertyId: UUID
    private var roomId: UUID?
    private var existingPhotos: [String] = []
    private let roomService: RoomService

    init(propertyId: UUID, roomService: RoomService, room: Room? = nil) {
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
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Decimal(string: monthlyRent) != nil
    }

    func save() async -> Room? {
        guard let rent = Decimal(string: monthlyRent) else { return nil }
        let size = Decimal(string: sizeSqm)
        isLoading = true
        errorMessage = nil
        do {
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
                let result = try await roomService.updateRoom(updated)
                isLoading = false
                return result
            } else {
                let result = try await roomService.createRoom(
                    propertyId: propertyId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    monthlyRent: rent,
                    roomType: roomType,
                    sizeSqm: size
                )
                isLoading = false
                return result
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
