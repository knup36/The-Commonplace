// ScrapbookJournalCard.swift
// Commonplace
//
// Scrapbook feed card for .journal entries.
// Renders as a torn notebook page — ruled lines, red margin line,
// ragged top edge where it was torn from the spiral binding.
//
// Layout:
//   - Ragged top edge (torn paper effect)
//   - Date header at top in handwriting-style
//   - Weather/mood/vibe emojis if available
//   - Ruled lines running across the card
//   - Journal text overlaid on the ruled lines
//   - Red margin line on the left
//
// No rotation — journal pages are pressed flat into the scrapbook.
// Ragged edge is deterministic per entry UUID.

import SwiftUI

struct ScrapbookJournalCard: View {
    let entry: Entry

    private let cardWidth: CGFloat = 300
    private let lineSpacing: CGFloat = 24
    private let marginX: CGFloat = 36
    private let ruleColor = Color(red: 0.75, green: 0.85, blue: 0.92).opacity(0.8)
    private let marginColor = Color(red: 0.85, green: 0.25, blue: 0.25).opacity(0.5)
    private let paperColor = Color(red: 0.97, green: 0.96, blue: 0.91)

    var previewText: String {
        let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "" : text
    }

    var emojis: String {
        [entry.weatherEmoji, entry.moodEmoji, entry.vibeEmoji]
            .filter { !$0.isEmpty }
            .joined(separator: "  ")
    }

    /// Ragged top edge heights seeded from UUID
    func raggedTopOffsets(steps: Int) -> [CGFloat] {
        var result: [CGFloat] = []
        var hash = abs(entry.id.uuidString.hashValue)
        for _ in 0..<steps {
            hash = hash &* 1664525 &+ 1013904223
            let normalized = CGFloat(abs(hash) % 100) / 100.0
            result.append(normalized * 10)
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Ragged torn top edge
            TornEdge(seed: entry.id.uuidString)
                .fill(paperColor)
                .frame(height: 16)

            // Notebook page body
            ZStack(alignment: .topLeading) {
                // Paper background
                paperColor

                // Ruled lines
                RuledLines(
                    lineSpacing: lineSpacing,
                    lineColor: ruleColor,
                    marginX: marginX,
                    marginColor: marginColor
                )

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Date
                    Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                        .font(.custom("Georgia", size: 13))
                        .italic()
                        .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.7).opacity(0.8))

                    // Emojis
                    if !emojis.isEmpty {
                        Text(emojis)
                            .font(.system(size: 16))
                    }

                    // Journal text
                    if !previewText.isEmpty {
                        Text(previewText)
                            .font(.custom("Georgia", size: 14))
                            .foregroundStyle(ScrapbookTheme.inkPrimary)
                            .lineSpacing(lineSpacing - 14)
                            .lineLimit(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, marginX + 8)
                .padding(.trailing, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
        .frame(width: cardWidth)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 4,
                topTrailingRadius: 0
            )
        )
        .shadow(color: .black.opacity(0.12), radius: 6, x: 1, y: 3)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Torn Edge Shape

struct TornEdge: Shape {
    let seed: String
    let steps = 20

    func offsets() -> [CGFloat] {
        var result: [CGFloat] = []
        var hash = abs(seed.hashValue)
        for _ in 0..<steps {
            hash = hash &* 1664525 &+ 1013904223
            let normalized = CGFloat(abs(hash) % 100) / 100.0
            result.append(normalized * 12)
        }
        return result
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let offs = offsets()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: offs[0]))

        for i in 1..<steps {
            let x = rect.minX + (rect.width / CGFloat(steps - 1)) * CGFloat(i)
            path.addLine(to: CGPoint(x: x, y: offs[i]))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Ruled Lines

struct RuledLines: View {
    let lineSpacing: CGFloat
    let lineColor: Color
    let marginX: CGFloat
    let marginColor: Color

    var body: some View {
        Canvas { context, size in
            // Horizontal ruled lines
            var y: CGFloat = 44
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                y += lineSpacing
            }

            // Red margin line
            var marginPath = Path()
            marginPath.move(to: CGPoint(x: marginX, y: 0))
            marginPath.addLine(to: CGPoint(x: marginX, y: size.height))
            context.stroke(marginPath, with: .color(marginColor), lineWidth: 1)
        }
    }
}
