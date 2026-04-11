// ScrapbookSoundCard.swift
// Commonplace
//
// Scrapbook feed card for .audio entries.
// Minimal floating design — no container, just elements on the paper.
// Waveform bars are pseudo-random heights seeded from entry UUID
// so each sound entry has its own unique waveform fingerprint.
//
// Layout:
//   - Waveform visualization centered, bars in entry accent brown
//   - Play button circle centered below waveform
//   - Transcript preview if available, italic serif
//   - Date centered at bottom in small caps
//
// No rotation — sound feels calm and settled on the page.
// No container — floats directly on the cream paper like Note cards.

import SwiftUI

struct ScrapbookSoundCard: View {
    let entry: Entry
    
    private let barCount = 32
    private let maxBarHeight: CGFloat = 48
    private let minBarHeight: CGFloat = 4
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    
    /// Deterministic bar heights seeded from entry UUID
    var barHeights: [CGFloat] {
        var result: [CGFloat] = []
        var hash = abs(entry.id.uuidString.hashValue)
        for _ in 0..<barCount {
            hash = hash &* 1664525 &+ 1013904223
            let normalized = CGFloat(abs(hash) % 100) / 100.0
            // Shape the waveform — taller in the middle, shorter at edges
            let position = CGFloat(result.count) / CGFloat(barCount)
            let envelope = sin(position * .pi)
            let height = minBarHeight + (maxBarHeight - minBarHeight) * normalized * (0.4 + envelope * 0.6)
            result.append(height)
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Waveform + play button inline
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .center, spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { i in
                        RoundedRectangle(cornerRadius: barWidth / 2)
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: barWidth, height: barHeights[i])
                            .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                }
                .frame(height: maxBarHeight)
                
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        .frame(width: 44, height: 44)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.orange.opacity(0.8))
                        .offset(x: 2)
                }
                .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 2)
            }
            .padding(.horizontal, 24)
            
            // Transcript preview
            if let transcript = entry.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(ScrapbookTheme.bodyFont(size: 14))
                    .italic()
                    .foregroundStyle(ScrapbookTheme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
            }
            
            // Date
            Text(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))
                .font(ScrapbookTheme.captionFont(size: 13))
                .kerning(1.2)
                .foregroundStyle(Color.orange.opacity(0.7))
                .shadow(color: .orange.opacity(0.2), radius: 2, x: 0, y: 1)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }
}
