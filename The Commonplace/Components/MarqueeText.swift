// MarqueeText.swift
// Commonplace
//
// Scrolling text component for text that exceeds its container width.
// Mimics the iOS Music app's marquee scroll for long track names.
//
// Behaviour:
//   - If text fits within available width — displays statically, no animation
//   - If text overflows — scrolls left continuously, looping seamlessly
//
// Scroll pattern:
//   1. Pause at start
//   2. Scroll left smoothly (first copy exits, second copy enters from right)
//   3. Snap back invisibly
//   4. Repeat
//
// Uses Swift concurrency (Task) to prevent race conditions from multiple
// simultaneous loop calls — the previous task is always cancelled before
// starting a new one.

import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    var pauseDuration: Double = 5.0
    var scrollDuration: Double = 14.0

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var scrollTask: Task<Void, Never>? = nil

    var needsScroll: Bool {
        textWidth > containerWidth && textWidth > 0 && containerWidth > 0
    }

    var loopDistance: CGFloat {
        textWidth + 40
    }

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width

            ZStack(alignment: .leading) {
                // Hidden measurement text
                Text(text)
                    .font(font)
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .background(
                        GeometryReader { textGeo in
                            Color.clear
                                .onAppear {
                                    textWidth = textGeo.size.width
                                    containerWidth = available
                                    restartLoop()
                                }
                                .onChange(of: text) { _, _ in
                                    textWidth = textGeo.size.width
                                    restartLoop()
                                }
                        }
                    )

                if needsScroll {
                    HStack(spacing: 40) {
                        Text(text)
                            .font(font)
                            .foregroundStyle(color)
                            .fixedSize(horizontal: true, vertical: false)
                        Text(text)
                            .font(font)
                            .foregroundStyle(color)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .offset(x: offset)
                } else {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(width: available, alignment: .leading)
            .clipped()
            .onAppear {
                containerWidth = available
                restartLoop()
            }
            .onDisappear {
                scrollTask?.cancel()
                scrollTask = nil
            }
        }
        .frame(height: UIFont.preferredFont(forTextStyle: .body).lineHeight + 4)
    }

    // MARK: - Loop Control

    func restartLoop() {
        scrollTask?.cancel()
        scrollTask = nil
        offset = 0

        guard needsScroll else { return }

        scrollTask = Task {
            await runLoop()
        }
    }

    @MainActor
    func runLoop() async {
        while !Task.isCancelled {
            // Pause at start
            try? await Task.sleep(for: .seconds(pauseDuration))
            guard !Task.isCancelled else { break }

            // Scroll left
            withAnimation(.timingCurve(0.2, 0, 0.8, 1, duration: scrollDuration)) {
                offset = -loopDistance
            }

            // Wait for animation to finish
            try? await Task.sleep(for: .seconds(scrollDuration))
            guard !Task.isCancelled else { break }

            // Snap back instantly
            offset = 0

            // Brief pause before next loop
            try? await Task.sleep(for: .seconds(0.05))
        }
    }
}
