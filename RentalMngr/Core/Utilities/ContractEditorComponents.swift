import SwiftUI
import UIKit

// MARK: - Shared contract editor types

enum ContractEditorTab: String, CaseIterable {
    case editor = "Edit"
    case preview = "Preview"
}

// MARK: - UITextView wrapper for cursor-aware variable insertion

struct ContractTextEditor: UIViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true

    /// Holds a weak reference to the underlying UITextView for programmatic insertion.
    let textViewRef: TextViewRef

    final class TextViewRef {
        weak var textView: UITextView?
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.isUserInteractionEnabled = true
        // Let SwiftUI handle keyboard avoidance via the VStack layout —
        // disable UIScrollView's own automatic inset adjustment to avoid double-offset
        tv.contentInsetAdjustmentBehavior = .never
        textViewRef.textView = tv
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update text when it actually changed to avoid disrupting
        // the active editing session (which would dismiss the keyboard)
        if uiView.text != text {
            let selected = uiView.selectedRange
            uiView.text = text
            let len = (uiView.text as NSString).length
            if selected.location <= len {
                uiView.selectedRange = selected
            }
        }
        // Only toggle editability if it actually changed
        if uiView.isEditable != isEditable {
            uiView.isEditable = isEditable
        }
        context.coordinator.text = $text
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }

    /// Inserts `snippet` at the current cursor position (appends if no cursor available).
    func insertAtCursor(_ snippet: String) {
        guard let tv = textViewRef.textView else {
            text += snippet
            return
        }
        let nsText = tv.text as NSString
        let range = tv.selectedRange
        let newText = nsText.replacingCharacters(in: range, with: snippet)
        tv.text = newText
        text = newText
        let newCursor = range.location + (snippet as NSString).length
        tv.selectedRange = NSRange(location: newCursor, length: 0)
    }
}
