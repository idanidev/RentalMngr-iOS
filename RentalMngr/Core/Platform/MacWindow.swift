import SwiftUI

#if targetEnvironment(macCatalyst)
    import UIKit

    /// Sets a sensible minimum window size on Mac Catalyst so the sidebar +
    /// detail layout never collapses into an unusable sliver. Walks up to the
    /// hosting `UIWindowScene` once the view is attached to a window.
    private final class WindowConfigView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let scene = window?.windowScene else { return }
            scene.sizeRestrictions?.minimumSize = CGSize(width: 920, height: 640)
            // No maximum — let the user go full screen; content width is capped
            // per-view via `readableWidth()` instead of clamping the whole window.
            scene.titlebar?.titleVisibility = .hidden
            scene.titlebar?.toolbarStyle = .unified
        }
    }

    private struct MacWindowConfigurator: UIViewRepresentable {
        func makeUIView(context: Context) -> UIView { WindowConfigView() }
        func updateUIView(_ uiView: UIView, context: Context) {}
    }
#endif

extension View {
    /// Applies Mac Catalyst window setup (minimum size, titlebar). No-op elsewhere.
    func macWindowConfigured() -> some View {
        #if targetEnvironment(macCatalyst)
            background(MacWindowConfigurator().frame(width: 0, height: 0))
        #else
            self
        #endif
    }

    /// Native pointer hover affordance (lift) for Mac/iPad cards and pulsable cells,
    /// so the cursor signals interactivity (MAC_DESIGN §5). No-op on iPhone (no pointer).
    func macCardHover() -> some View {
        hoverEffect(.lift)
    }
}
