import SwiftUI

struct UndoToast: View {
    let message: String
    let duration: Double
    let onUndo: () -> Void
    let onExpire: () -> Void

    @State private var progress: CGFloat = 1.0
    @State private var visible = false

    var body: some View {
        HStack(spacing: 12) {
            // Countdown ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 22, height: 22)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: duration), value: progress)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Button {
                onUndo()
            } label: {
                Text("Undo")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .red).opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                visible = true
            }
            // Start countdown
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                progress = 0
            }
            // Expire
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.easeOut(duration: 0.3)) {
                    visible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onExpire()
                }
            }
        }
    }
}
