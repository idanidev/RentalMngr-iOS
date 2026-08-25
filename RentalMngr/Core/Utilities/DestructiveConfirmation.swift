import SwiftUI

/// Lo que se va a hacer y qué implica, para poder confirmarlo con conocimiento.
struct DestructiveAction: Identifiable {
    let id = UUID()
    /// Qué se va a hacer. Corto y concreto: "Quitar el acceso a Marta".
    let title: String
    /// Consecuencia real, en una frase. Aquí se dice también lo que NO pasa,
    /// que suele ser lo que de verdad preocupa ("sus datos no se borran").
    let message: String
    /// Texto del botón. Un verbo, nunca "OK": el botón debe decir qué hace.
    let confirmLabel: String
    let icon: String
    let perform: () async -> Void

    init(
        title: String, message: String, confirmLabel: String,
        icon: String = "exclamationmark.triangle.fill",
        perform: @escaping () async -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.icon = icon
        self.perform = perform
    }
}

extension View {
    /// Confirmación para acciones destructivas.
    ///
    /// Hoja propia en vez del diálogo del sistema por dos motivos: cabe explicar
    /// la consecuencia (el diálogo nativo deja el texto en gris diminuto) y el
    /// botón puede nombrar la acción en lugar de un "OK" que no dice nada.
    func destructiveConfirmation(_ action: Binding<DestructiveAction?>) -> some View {
        modifier(DestructiveConfirmationModifier(action: action))
    }
}

private struct DestructiveConfirmationModifier: ViewModifier {
    @Binding var action: DestructiveAction?
    @State private var isWorking = false

    func body(content: Content) -> some View {
        content.sheet(item: $action) { item in
            VStack(spacing: 20) {
                Image(systemName: item.icon)
                    .font(.system(size: 42))
                    .foregroundStyle(.red)
                    .padding(.top, 28)

                Text(item.title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text(item.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        let job = item.perform
                        Task {
                            isWorking = true
                            await job()
                            isWorking = false
                            action = nil
                        }
                    } label: {
                        Group {
                            if isWorking {
                                ProgressView().tint(.white)
                            } else {
                                Text(item.confirmLabel).fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .disabled(isWorking)

                    Button(String(localized: "Cancelar", locale: LanguageService.currentLocale, comment: "Cancel destructive action")) {
                        action = nil
                    }
                    .disabled(isWorking)
                }
            }
            .padding(24)
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(isWorking)
        }
    }
}
