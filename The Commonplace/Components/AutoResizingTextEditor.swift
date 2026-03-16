import SwiftUI

struct AutoResizingTextEditor: View {
    @Binding var text: String
    var placeholder: String = ""
    var font: Font = .body
    var minHeight: CGFloat = 32
    var onSubmit: (() -> Void)? = nil
    
    var body: some View {
        TextEditor(text: $text)
            .font(font)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: minHeight)
            .padding(.horizontal, -5)
            .padding(.vertical, -4)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(font)
                        .foregroundStyle(.tertiary)
                        .allowsHitTesting(false)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
            }
            .onChange(of: text) { _, newValue in
                if let onSubmit, newValue.hasSuffix("\n") {
                    text = String(newValue.dropLast())
                    onSubmit()
                }
            }
    }
}
