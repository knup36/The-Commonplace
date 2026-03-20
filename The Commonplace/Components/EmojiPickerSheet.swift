import SwiftUI

// MARK: - EmojiPickerSheet
// Native emoji keyboard presented as a sheet.
// Uses a hidden TextField trick to invoke the system emoji keyboard.
// Screen: Today tab → Journal card → Vibe picker

struct EmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text("Pick a Vibe")
                .font(.headline)
                .padding(.top, 24)

            TextField("", text: $text)
                .focused($focused)
                .keyboardType(.default)
                .onChange(of: text) { _, newValue in
                    // Extract only the first emoji character
                    if let emoji = newValue.unicodeScalars.first(where: { $0.properties.isEmoji && $0.value > 0x007F }) {
                        selectedEmoji = String(emoji)
                        text = ""
                    } else if !newValue.isEmpty {
                        text = ""
                    }
                }
                .frame(width: 1, height: 1)
                .opacity(0.01)

            Text("Tap below to open the emoji keyboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                focused = true
                // Trigger emoji keyboard
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIApplication.shared.windows.first?.rootViewController?
                        .view.endEditing(false)
                }
            } label: {
                Text("🎭")
                    .font(.system(size: 64))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focused = true
            }
        }
    }
}
