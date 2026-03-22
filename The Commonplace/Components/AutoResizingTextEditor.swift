import SwiftUI
import UIKit

struct AutoResizingTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: Font = .body
    var minHeight: CGFloat = 32
    var onSubmit: (() -> Void)? = nil

    // How long to wait after typing stops before syncing to SwiftData (in seconds)
    private let debounceInterval: TimeInterval = 0.3

    func makeUIView(context: Context) -> UITextView {
        let textView = GrowingTextView()
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.font = resolveUIFont(font)
        textView.minHeight = minHeight
        textView.text = text
        updatePlaceholder(textView, context: context)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update the text view if the change came from outside (e.g. programmatic reset)
        // not from the user typing — prevents cursor jumping mid-word
        if textView.text != text && !context.coordinator.isEditing {
            textView.text = text
            textView.invalidateIntrinsicContentSize()
            updatePlaceholder(textView, context: context)
        }
        // Always keep font in sync (e.g. theme changes)
        textView.font = resolveUIFont(font)
        if let growing = textView as? GrowingTextView {
            growing.minHeight = minHeight
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoResizingTextEditor
        var isEditing = false
        private var debounceTimer: Timer?

        init(_ parent: AutoResizingTextEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            hidePlaceholder(textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            // Flush immediately on blur — don't wait for debounce
            debounceTimer?.invalidate()
            parent.text = textView.text
            showPlaceholderIfNeeded(textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            // Tell SwiftUI the view needs more/less space
            textView.invalidateIntrinsicContentSize()

            // Handle onSubmit (newline detection)
            if let onSubmit = parent.onSubmit, textView.text.hasSuffix("\n") {
                textView.text = String(textView.text.dropLast())
                debounceTimer?.invalidate()
                parent.text = textView.text
                onSubmit()
                return
            }

            // Debounce: reset the timer on every keystroke.
            // Only syncs to SwiftData after typing pauses for debounceInterval.
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(
                withTimeInterval: parent.debounceInterval,
                repeats: false
            ) { [weak self] _ in
                guard let self else { return }
                self.parent.text = textView.text
            }
        }

        // MARK: - Placeholder helpers

        private func hidePlaceholder(_ textView: UITextView) {
            textView.subviews
                .first(where: { $0.accessibilityIdentifier == "placeholder" })?
                .removeFromSuperview()
        }

        private func showPlaceholderIfNeeded(_ textView: UITextView) {
            if textView.text.isEmpty {
                addPlaceholder(to: textView, text: parent.placeholder, font: textView.font)
            }
        }

        func addPlaceholder(to textView: UITextView, text: String?, font: UIFont?) {
            guard let text, !text.isEmpty else { return }
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

    /// UITextView subclass that self-reports its content height to SwiftUI,
    /// growing freely as text is added while respecting a minimum height.
    class GrowingTextView: UITextView {
        var minHeight: CGFloat = 32

        override var intrinsicContentSize: CGSize {
            let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
            let size = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            return CGSize(width: UIView.noIntrinsicMetric, height: max(size.height, minHeight))
        }
    }

    // MARK: - Helpers

    private func updatePlaceholder(_ textView: UITextView, context: Context) {
        if text.isEmpty && !placeholder.isEmpty {
            context.coordinator.addPlaceholder(
                to: textView,
                text: placeholder,
                font: resolveUIFont(font)
            )
        }
    }

    /// Converts SwiftUI Font to UIFont so UITextView renders correctly
    private func resolveUIFont(_ font: Font) -> UIFont {
        switch font {
        case .largeTitle:   return UIFont.preferredFont(forTextStyle: .largeTitle)
        case .title:        return UIFont.preferredFont(forTextStyle: .title1)
        case .title2:       return UIFont.preferredFont(forTextStyle: .title2)
        case .title3:       return UIFont.preferredFont(forTextStyle: .title3)
        case .headline:     return UIFont.preferredFont(forTextStyle: .headline)
        case .subheadline:  return UIFont.preferredFont(forTextStyle: .subheadline)
        case .body:         return UIFont.preferredFont(forTextStyle: .body)
        case .callout:      return UIFont.preferredFont(forTextStyle: .callout)
        case .footnote:     return UIFont.preferredFont(forTextStyle: .footnote)
        case .caption:      return UIFont.preferredFont(forTextStyle: .caption1)
        case .caption2:     return UIFont.preferredFont(forTextStyle: .caption2)
        default:            return UIFont.preferredFont(forTextStyle: .body)
        }
    }
}
