import PhotosUI
import SwiftUI

struct RoomFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RoomFormViewModel?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []

    let propertyId: UUID
    let room: Room?

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(
            String(localized: room == nil ? "New room" : "Edit room",
                locale: LanguageService.currentLocale, comment: "Navigation title for room form")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", locale: LanguageService.currentLocale, comment: "Button to cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save", locale: LanguageService.currentLocale, comment: "Button to save")) {
                    Task {
                        if await viewModel?.save(newPhotos: photoData) != nil {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel?.isFormValid != true || viewModel?.isLoading == true)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = RoomFormViewModel(
                    roomService: appState.roomService,
                    propertyId: propertyId,
                    room: room
                )
            }
        }
    }

    @ViewBuilder
    private func formContent(_ vm: RoomFormViewModel) -> some View {
        Form {
            Section(String(localized: "Information", locale: LanguageService.currentLocale, comment: "Section header for room info")) {
                TextField(
                    String(localized: "Name", locale: LanguageService.currentLocale, comment: "Room name field placeholder"),
                    text: Binding(get: { vm.name }, set: { vm.name = $0 }))

                Picker(
                    String(localized: "Type", locale: LanguageService.currentLocale, comment: "Room type picker label"),
                    selection: Binding(get: { vm.roomType }, set: { vm.roomType = $0 })
                ) {
                    Text("Private", comment: "Private room type option").tag(RoomType.privateRoom)
                    Text("Common", comment: "Common room type option").tag(RoomType.common)
                }

                if vm.roomType == .privateRoom {
                    TextField(
                        String(localized: "Monthly rent (€)", locale: LanguageService.currentLocale, comment: "Monthly rent field placeholder"),
                        text: Binding(get: { vm.monthlyRent }, set: { vm.monthlyRent = $0 })
                    )
                    .keyboardType(.decimalPad)
                }

                TextField(
                    String(localized: "Size m² (optional)", locale: LanguageService.currentLocale, comment: "Room size field placeholder"),
                    text: Binding(get: { vm.sizeSqm }, set: { vm.sizeSqm = $0 })
                )
                .keyboardType(.decimalPad)
            }

            Section(String(localized: "Photos", locale: LanguageService.currentLocale, comment: "Section header for photos")) {
                if !vm.existingPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.existingPhotos, id: \.self) { path in
                                let url = URL(
                                    string:
                                        "\(SupabaseConfig.url.absoluteString)/storage/v1/object/public/\(SupabaseConfig.storageBucket)/\(path)"
                                )
                                ZStack(alignment: .topTrailing) {
                                    AsyncImageView(url: url, contentMode: .fill, targetSize: CGSize(width: 80, height: 80))
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button {
                                        withAnimation {
                                            vm.deletePhoto(path)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white, .red)
                                    }
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                PhotoPickerView(
                    selectedItems: $selectedPhotos, images: $photoData,
                    maxCount: 10 - vm.existingPhotos.count)
            }

            Section(String(localized: "Notes", locale: LanguageService.currentLocale, comment: "Section header for notes")) {
                TextField(
                    String(localized: "Notes (optional)", locale: LanguageService.currentLocale, comment: "Notes field placeholder"),
                    text: Binding(get: { vm.notes }, set: { vm.notes = $0 }),
                    axis: .vertical
                )
                .lineLimit(3...6)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .loadingOverlay(vm.isLoading)
    }
}
