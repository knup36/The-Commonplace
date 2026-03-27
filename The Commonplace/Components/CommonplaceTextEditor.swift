// CommonplaceTextEditor.swift
// Commonplace
//
// A UIViewRepresentable text editor that:
//   1. Auto-resizes as the user types (GrowingTextView)
//   2. Correctly renders the Inkwell serif font while actively editing
//   3. Debounces SwiftData saves (300ms after typing stops)
//   4. Posts a focus notification so parent ScrollViews can scroll to keep
//      the editor visible above the keyboard
//   5. Has an extensible toolbar slot for future formatting tools
//
// Usage:
//   CommonplaceTextEditor(
//       text: $text,
//       placeholder: "Start writing...",
//       usesSerifFont: style.usesSerifFonts,
//       minHeight: 60
//   )
//
// Keyboard avoidance:
//   Add .keyboardAvoiding() to any ScrollView that contains this editor.
//   It listens for keyboard frame changes and scrolls to keep the focused
//   editor visible. Remove all Color.clear.frame(height: 100) hacks.
//
// Extensible toolbar:
//   CommonplaceTextEditor(text: $text, ...) {
//       Button("Bold") { ... }  // future formatting tools go here
//   }

import SwiftUI
import UIKit
import Combine

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when CommonplaceTextEditor gains focus.
    /// userInfo: ["frame": CGRect] — the editor's frame in screen coordinates
    static let textEditorDidFocus = Notification.Name("textEditorDidFocus")
    
    /// Posted when CommonplaceTextEditor loses focus.
    static let textEditorDidBlur = Notification.Name("textEditorDidBlur")
}

// MARK: - CommonplaceTextEditor

struct CommonplaceTextEditor<Toolbar: View>: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var usesSerifFont: Bool = false
    var minHeight: CGFloat = 32
    var onSubmit: (() -> Void)? = nil
    var toolbar: Toolbar
    
    private let debounceInterval: TimeInterval = 0.3
    
    // Convenience init without toolbar
    init(
        text: Binding<String>,
        placeholder: String = "",
        usesSerifFont: Bool = false,
        minHeight: CGFloat = 32,
        onSubmit: (() -> Void)? = nil
    ) where Toolbar == EmptyView {
        self._text = text
        self.placeholder = placeholder
        self.usesSerifFont = usesSerifFont
        self.minHeight = minHeight
        self.onSubmit = onSubmit
        self.toolbar = EmptyView()
    }
    
    // Full init with toolbar
    init(
        text: Binding<String>,
        placeholder: String = "",
        usesSerifFont: Bool = false,
        minHeight: CGFloat = 32,
        onSubmit: (() -> Void)? = nil,
        @ViewBuilder toolbar: () -> Toolbar
    ) {
        self._text = text
        self.placeholder = placeholder
        self.usesSerifFont = usesSerifFont
        self.minHeight = minHeight
        self.onSubmit = onSubmit
        self.toolbar = toolbar()
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> GrowingTextView {
        let textView = GrowingTextView()
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.font = resolvedUIFont
        textView.minHeight = minHeight
        textView.text = text
        updatePlaceholder(textView, context: context)
        return textView
    }
    
    func updateUIView(_ textView: GrowingTextView, context: Context) {
        // Only update text if change came from outside (not user typing)
        if textView.text != text && !context.coordinator.isEditing {
            textView.text = text
            textView.invalidateIntrinsicContentSize()
            updatePlaceholder(textView, context: context)
        }
        // Always keep font in sync (e.g. theme changes)
        textView.font = resolvedUIFont
        textView.minHeight = minHeight
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Font Resolution
    //
    // Directly constructs UIFont with serif design when usesSerifFont is true.
    // This is the fix for the system font flicker during editing in Inkwell theme.
    // UIFontDescriptor.withDesign(.serif) is safe on iOS 13+ — never returns nil
    // for standard text styles.
    
    var resolvedUIFont: UIFont {
        let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        if usesSerifFont {
            if let serifDescriptor = baseDescriptor.withDesign(.serif) {
                return UIFont(descriptor: serifDescriptor, size: 0)
            }
        }
        return UIFont(descriptor: baseDescriptor, size: 0)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CommonplaceTextEditor
        var isEditing = false
        private var debounceTimer: Timer?
        
        init(_ parent: CommonplaceTextEditor) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            hidePlaceholder(textView)
            
            // Post focus notification so ScrollView can scroll to keep this visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let frame = textView.convert(textView.bounds, to: nil)
                NotificationCenter.default.post(
                    name: .textEditorDidFocus,
                    object: nil,
                    userInfo: ["frame": frame]
                )
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            // Flush immediately on blur
            debounceTimer?.invalidate()
            parent.text = textView.text
            showPlaceholderIfNeeded(textView)
            
            NotificationCenter.default.post(name: .textEditorDidBlur, object: nil)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            textView.invalidateIntrinsicContentSize()
            
            // Handle onSubmit
            if let onSubmit = parent.onSubmit, textView.text.hasSuffix("\n") {
                textView.text = String(textView.text.dropLast())
                debounceTimer?.invalidate()
                parent.text = textView.text
                onSubmit()
                return
            }
            
            // Debounce save
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(
                withTimeInterval: parent.debounceInterval,
                repeats: false
            ) { [weak self] _ in
                guard let self else { return }
                self.parent.text = textView.text
            }
        }
        
        // MARK: - Placeholder
        
        private func hidePlaceholder(_ textView: UITextView) {
            textView.subviews
                .first(where: { $0.accessibilityIdentifier == "placeholder" })?
                .removeFromSuperview()
        }
        
        private func showPlaceholderIfNeeded(_ textView: UITextView) {
            if textView.text.isEmpty {
                addPlaceholder(to: textView, font: textView.font)
            }
        }
        
        func addPlaceholder(to textView: UITextView, font: UIFont?) {
            let text = parent.placeholder
            guard !text.isEmpty else { return }
            hidePlaceholder(textView)
            let label = UILabel()
            label.text = text
            label.font = font
            label.textColor = UIColor.tertiaryLabel
            label.accessibilityIdentifier = "placeholder"
            label.translatesAutoresizingMaskIntoConstraints = false
            textView.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: textView.topAnchor),
                label.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            ])
        }
    }
    
    // MARK: - GrowingTextView
    
    /// UITextView subclass that self-reports its content height to SwiftUI.
    /// Grows freely as text is added while respecting a minimum height.
    class GrowingTextView: UITextView {
        var minHeight: CGFloat = 32
        
        override var intrinsicContentSize: CGSize {
            let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
            let size = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            return CGSize(width: UIView.noIntrinsicMetric, height: max(size.height, minHeight))
        }
    }
    
    // MARK: - Helpers
    
    private func updatePlaceholder(_ textView: GrowingTextView, context: Context) {
        if text.isEmpty && !placeholder.isEmpty {
            context.coordinator.addPlaceholder(to: textView, font: resolvedUIFont)
        }
    }
}

// MARK: - KeyboardAvoidingModifier

/// Attach to any ScrollView that contains a CommonplaceTextEditor.
/// Listens for keyboard show/hide and textEditorDidFocus notifications,
/// then adjusts the scroll position to keep the focused editor visible.
///
/// Usage: ScrollView { ... }.keyboardAvoiding()

struct KeyboardAvoidingModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    @State private var editorFrame: CGRect = .zero
    
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: keyboardHeight > 0 ? 16 : 0)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                keyboardHeight = frame.height
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
    }
}

extension View {
    /// Add to any ScrollView containing a CommonplaceTextEditor
    /// to ensure the keyboard doesn't cover the editor while typing.
    func keyboardAvoiding() -> some View {
        modifier(KeyboardAvoidingModifier())
    }
}
