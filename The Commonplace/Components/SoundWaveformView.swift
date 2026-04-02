// SoundWaveformView.swift
// Commonplace
//
// Reusable animated waveform component for Sound entries.
// Shows a row of bars at varying heights using a seeded random
// pattern so the same entry always shows the same waveform shape.
//
// Two modes:
//   .static   — bars at fixed heights, no animation
//   .playing  — bars animate up and down while playing
//
// The bar pattern is seeded from the entry ID so each sound
// entry has a unique but consistent waveform shape.

import SwiftUI

struct SoundWaveformView: View {
    let entryID: UUID
    let accentColor: Color
    let isPlaying: Bool
    let barCount: Int
    let height: CGFloat

    init(
        entryID: UUID,
        accentColor: Color,
        isPlaying: Bool = false,
        barCount: Int = 20,
        height: CGFloat = 28
    ) {
        self.entryID = entryID
        self.accentColor = accentColor
        self.isPlaying = isPlaying
        self.barCount = barCount
        self.height = height
    }

    // Generate consistent bar heights from entry ID
    var barHeights: [CGFloat] {
        let seed = entryID.uuidString
            .unicodeScalars
            .reduce(0) { $0 + Int($1.value) }
        var rng = SeededRandom(seed: seed)
        return (0..<barCount).map { _ in
            CGFloat.random(in: 0.25...1.0, using: &rng)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { i in
                let baseHeight = barHeights[i] * height
                let barHeight: CGFloat = isPlaying
                    ? max(3, baseHeight * playingMultiplier(for: i))
                    : max(3, baseHeight)

                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .opacity(0.85)
                    .frame(width: 3, height: barHeight)
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: 0.35 + Double(i % 4) * 0.07)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i % 6) * 0.04)
                            : .easeOut(duration: 0.2),
                        value: isPlaying
                    )
            }
        }
        .frame(height: height)
    }

    func playingMultiplier(for index: Int) -> CGFloat {
        // Each bar gets a slightly different multiplier so they
        // move independently rather than all together
        let multipliers: [CGFloat] = [0.6, 1.0, 0.75, 0.9, 0.5, 0.85, 0.7, 0.95]
        return multipliers[index % multipliers.count]
    }
}

// MARK: - Seeded Random

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
