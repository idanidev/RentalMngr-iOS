import SwiftUI
import UserNotifications

// MARK: - Setup Steps

private enum SetupStep: Int, CaseIterable {
    case property = 0
    case room = 1
    case notifications = 2
    case done = 3
}

// MARK: - ViewModel

@MainActor @Observable
final class OnboardingSetupViewModel {
    // Property step
    var propertyName = ""
    var propertyAddress = ""

    // Room step
    var roomName = ""
    var roomRent = ""

    var isLoading = false
    var errorMessage: String?
    private(set) var createdPropertyId: UUID?
    private(set) var createdRoomName: String?

    private let propertyService: PropertyServiceProtocol
    private let roomService: RoomServiceProtocol
    private let userId: UUID

    var isPropertyValid: Bool {
        !propertyName.trimmingCharacters(in: .whitespaces).isEmpty
            && !propertyAddress.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(
        propertyService: PropertyServiceProtocol,
        roomService: RoomServiceProtocol,
        userId: UUID
    ) {
        self.propertyService = propertyService
        self.roomService = roomService
        self.userId = userId
    }

    func createProperty() async -> Bool {
        guard isPropertyValid else { return false }
        isLoading = true
        errorMessage = nil
        do {
            let property = try await propertyService.createProperty(
                name: propertyName.trimmingCharacters(in: .whitespaces),
                address: propertyAddress.trimmingCharacters(in: .whitespaces),
                description: nil,
                ownerId: userId
            )
            createdPropertyId = property.id
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func createRoom() async -> Bool {
        guard let propertyId = createdPropertyId else { return false }
        let name = roomName.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "Room 1", locale: LanguageService.currentLocale, comment: "Default room name in setup")
            : roomName.trimmingCharacters(in: .whitespaces)
        let rent = Decimal(string: roomRent.replacingOccurrences(of: ",", with: ".")) ?? 0
        isLoading = true
        errorMessage = nil
        do {
            _ = try await roomService.createRoom(
                propertyId: propertyId,
                name: name,
                monthlyRent: rent,
                roomType: .privateRoom,
                sizeSqm: nil
            )
            createdRoomName = name
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}

// MARK: - OnboardingSetupView

struct OnboardingSetupView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var currentStep: SetupStep = .property
    @State private var viewModel: OnboardingSetupViewModel?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if let vm = viewModel {
                VStack(spacing: 0) {
                    // Progress bar
                    SetupProgressBar(currentStep: currentStep)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    // Step content
                    Group {
                        switch currentStep {
                        case .property:
                            PropertyStepView(vm: vm) {
                                Task {
                                    if await vm.createProperty() {
                                        advance()
                                    }
                                }
                            }
                        case .room:
                            RoomStepView(vm: vm) {
                                Task {
                                    _ = await vm.createRoom()
                                    advance()
                                }
                            } onSkip: {
                                advance()
                            }
                        case .notifications:
                            NotificationsStepView {
                                Task {
                                    await requestNotifications()
                                    advance()
                                }
                            } onSkip: {
                                advance()
                            }
                        case .done:
                            DoneStepView(vm: vm) {
                                hasCompletedSetup = true
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
        }
        .task {
            if viewModel == nil, let userId = appState.authService.currentUserId {
                viewModel = OnboardingSetupViewModel(
                    propertyService: appState.propertyService,
                    roomService: appState.roomService,
                    userId: userId
                )
            }
        }
    }

    private func advance() {
        let next = currentStep.rawValue + 1
        if let nextStep = SetupStep(rawValue: next) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = nextStep
            }
        }
    }

    private func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }
}

// MARK: - Progress Bar

private struct SetupProgressBar: View {
    let currentStep: SetupStep
    private let totalSteps = SetupStep.allCases.count

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                if index > 0 {
                    Rectangle()
                        .fill(index <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
                Circle()
                    .fill(index <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 10, height: 10)
                    .overlay {
                        if index < currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }
}

// MARK: - Step 1: Property

private struct PropertyStepView: View {
    @Bindable var vm: OnboardingSetupViewModel
    let onContinue: () -> Void
    @FocusState private var focusedField: Field?
    private enum Field { case name, address }

    var body: some View {
        SetupStepContainer(
            icon: "building.2.fill",
            iconColor: .blue,
            title: String(localized: "Create Your First Property", locale: LanguageService.currentLocale, comment: "Setup step 1 title"),
            subtitle: String(localized: "Start by adding the property you want to manage.", locale: LanguageService.currentLocale, comment: "Setup step 1 subtitle")
        ) {
            VStack(spacing: 14) {
                SetupTextField(
                    label: String(localized: "Property name", locale: LanguageService.currentLocale, comment: "Setup field label"),
                    placeholder: String(localized: "e.g. Calle Mayor 12", locale: LanguageService.currentLocale, comment: "Property name placeholder"),
                    text: $vm.propertyName,
                    icon: "building.2"
                )
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .address }

                SetupTextField(
                    label: String(localized: "Address", locale: LanguageService.currentLocale, comment: "Setup field label"),
                    placeholder: String(localized: "Street, city", locale: LanguageService.currentLocale, comment: "Address placeholder"),
                    text: $vm.propertyAddress,
                    icon: "mappin.circle"
                )
                .focused($focusedField, equals: .address)
                .submitLabel(.done)
                .onSubmit { if vm.isPropertyValid { onContinue() } }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } footer: {
            SetupPrimaryButton(
                title: String(localized: "Create Property", locale: LanguageService.currentLocale, comment: "Setup create property button"),
                isLoading: vm.isLoading,
                isEnabled: vm.isPropertyValid,
                action: onContinue
            )
        }
        .onAppear { focusedField = .name }
    }
}

// MARK: - Step 2: Room

private struct RoomStepView: View {
    @Bindable var vm: OnboardingSetupViewModel
    let onContinue: () -> Void
    let onSkip: () -> Void
    @FocusState private var focusedField: Field?
    private enum Field { case name, rent }

    var body: some View {
        SetupStepContainer(
            icon: "bed.double.fill",
            iconColor: .purple,
            title: String(localized: "Add a Room", locale: LanguageService.currentLocale, comment: "Setup step 2 title"),
            subtitle: String(localized: "Rooms are where your tenants live. You can add more later.", locale: LanguageService.currentLocale, comment: "Setup step 2 subtitle")
        ) {
            VStack(spacing: 14) {
                SetupTextField(
                    label: String(localized: "Room name", locale: LanguageService.currentLocale, comment: "Setup field label"),
                    placeholder: String(localized: "e.g. Room 1, Studio A", locale: LanguageService.currentLocale, comment: "Room name placeholder"),
                    text: $vm.roomName,
                    icon: "bed.double"
                )
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .rent }

                SetupTextField(
                    label: String(localized: "Monthly rent (€)", locale: LanguageService.currentLocale, comment: "Setup field label"),
                    placeholder: "500",
                    text: $vm.roomRent,
                    icon: "eurosign.circle",
                    keyboardType: .decimalPad
                )
                .focused($focusedField, equals: .rent)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } footer: {
            VStack(spacing: 12) {
                SetupPrimaryButton(
                    title: String(localized: "Add Room", locale: LanguageService.currentLocale, comment: "Setup add room button"),
                    isLoading: vm.isLoading,
                    isEnabled: true,
                    action: onContinue
                )
                Button(String(localized: "Skip for now", locale: LanguageService.currentLocale, comment: "Setup skip button"), action: onSkip)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { focusedField = .name }
    }
}

// MARK: - Step 3: Notifications

private struct NotificationsStepView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        SetupStepContainer(
            icon: "bell.badge.fill",
            iconColor: .orange,
            title: String(localized: "Enable Alerts", locale: LanguageService.currentLocale, comment: "Setup step 3 title"),
            subtitle: String(localized: "Stay ahead of important dates without having to open the app.", locale: LanguageService.currentLocale, comment: "Setup step 3 subtitle")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                NotificationBenefit(
                    icon: "doc.text.fill",
                    color: .red,
                    text: String(localized: "Contract expiry reminders (30, 15, 7 days before)", locale: LanguageService.currentLocale, comment: "Notification benefit")
                )
                NotificationBenefit(
                    icon: "eurosign.circle.fill",
                    color: .green,
                    text: String(localized: "Upcoming rent payment reminders", locale: LanguageService.currentLocale, comment: "Notification benefit")
                )
                NotificationBenefit(
                    icon: "calendar.badge.clock",
                    color: .blue,
                    text: String(localized: "Custom reminders you create yourself", locale: LanguageService.currentLocale, comment: "Notification benefit")
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } footer: {
            VStack(spacing: 12) {
                SetupPrimaryButton(
                    title: String(localized: "Enable Notifications", locale: LanguageService.currentLocale, comment: "Setup enable notifications button"),
                    isLoading: false,
                    isEnabled: true,
                    action: onContinue
                )
                Button(String(localized: "Not now", locale: LanguageService.currentLocale, comment: "Setup skip notifications button"), action: onSkip)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NotificationBenefit: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, alignment: .center)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Step 4: Done

private struct DoneStepView: View {
    let vm: OnboardingSetupViewModel
    let onFinish: () -> Void
    @State private var checkmarkVisible = false

    var body: some View {
        SetupStepContainer(
            icon: nil,
            iconColor: .green,
            title: String(localized: "All Set!", locale: LanguageService.currentLocale, comment: "Setup done title"),
            subtitle: String(localized: "Your workspace is ready. Here's what we created:", locale: LanguageService.currentLocale, comment: "Setup done subtitle")
        ) {
            VStack(spacing: 0) {
                // Big checkmark animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 76, height: 76)
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.green)
                        .scaleEffect(checkmarkVisible ? 1 : 0.3)
                        .opacity(checkmarkVisible ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: checkmarkVisible)
                }
                .padding(.bottom, 28)

                // Summary cards
                VStack(spacing: 10) {
                    if let propertyName = vm.createdPropertyId != nil ? vm.propertyName : nil {
                        SummaryRow(
                            icon: "building.2.fill",
                            color: .blue,
                            text: propertyName
                        )
                    }
                    if let roomName = vm.createdRoomName {
                        SummaryRow(
                            icon: "bed.double.fill",
                            color: .purple,
                            text: roomName
                        )
                    }
                }
            }
        } footer: {
            SetupPrimaryButton(
                title: String(localized: "Start Using RentalMngr", locale: LanguageService.currentLocale, comment: "Setup finish button"),
                isLoading: false,
                isEnabled: true,
                action: onFinish
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                checkmarkVisible = true
            }
        }
    }
}

private struct SummaryRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, alignment: .center)
            Text(text)
                .font(.subheadline.weight(.medium))
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Shared Components

private struct SetupStepContainer<Content: View, Footer: View>: View {
    let icon: String?
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Icon (optional — Done step uses its own)
                    if let icon {
                        ZStack {
                            Circle()
                                .fill(iconColor.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: icon)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(iconColor)
                        }
                    }

                    // Title + subtitle
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.title2.bold())
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Step-specific content
                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }

            // Footer buttons
            VStack {
                Divider()
                footer
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
        }
    }
}

private struct SetupTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct SetupPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? Color.accentColor : Color.secondary.opacity(0.3))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!isEnabled || isLoading)
    }
}
