// MoodTimelineCard.swift
// Commonplace
//
// Chronicles card showing a 7-day mood sentiment line graph.
// Receives pre-filtered journalEntries from ChroniclesView —
// no filtering performed at render time.
//
// Updated v2.4 — pre-filtered data, 7-day window, larger dots,
//               line graph replacing emoji stems.

import SwiftUI

struct MoodTimelineCard: View {
    let journalEntries: [Entry]
    var style: any AppThemeStyle

    @EnvironmentObject var themeManager: ThemeManager
    @State private var offset: Int = 0

    private let chartHeight: CGFloat = 140
    private let minScore: CGFloat = 1
    private let maxScore: CGFloat = 10
    private let dowLabels = ["S","M","T","W","T","F","S"]

    var windowDates: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<7).reversed().map { i in
            Calendar.current.date(byAdding: .day, value: -(i + offset * 7), to: today)!
        }
    }

    var windowEntries: [Entry?] {
        windowDates.map { date in
            journalEntries.first {
                Calendar.current.isDate($0.createdAt, inSameDayAs: date) &&
                !$0.moodEmoji.isEmpty
            }
        }
    }

    var moodCount: Int { windowEntries.compactMap { $0 }.count }

    var dateRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        guard let first = windowDates.first, let last = windowDates.last else { return "" }
        return "\(fmt.string(from: first)) — \(fmt.string(from: last))"
    }

    var body: some View {
        ChroniclesCardContainer(title: "Mood", icon: "waveform.path.ecg", background: .parchment) {
            if moodCount < 2 {
                Text("Start journaling to see your mood patterns over time.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(Color.white.opacity(0.4))
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Text(dateRangeLabel)
                            .font(style.typeCaption)
                            .foregroundStyle(Color.white.opacity(0.4))
                        Spacer()
                        HStack(spacing: 6) {
                            Button { withAnimation { offset += 1 } } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .frame(width: 24, height: 24)
                                    .overlay(RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            if offset > 0 {
                                Button { withAnimation { offset = max(0, offset - 1) } } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                        .frame(width: 24, height: 24)
                                        .overlay(RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    GeometryReader { geo in
                        let colWidth = geo.size.width / 7
                        lineChart(geo: geo, colWidth: colWidth)
                    }
                    .frame(height: chartHeight)

                    HStack(spacing: 0) {
                        ForEach(Array(windowDates.enumerated()), id: \.offset) { i, date in
                            let dow = Calendar.current.component(.weekday, from: date) - 1
                            Text(dowLabels[dow])
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.3))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    func scoreToY(_ score: CGFloat, height: CGFloat) -> CGFloat {
        let padding: CGFloat = 8
        let normalized = (score - minScore) / (maxScore - minScore)
        return padding + (1 - normalized) * (height - padding * 2)
    }

    @ViewBuilder
    func lineChart(geo: GeometryProxy, colWidth: CGFloat) -> some View {
        let height = chartHeight
        let points: [(index: Int, x: CGFloat, y: CGFloat, entry: Entry)] = windowEntries
            .enumerated()
            .compactMap { i, entry in
                guard let entry,
                      let score = MoodOption.score(for: entry.moodEmoji)
                else { return nil }
                let x = colWidth * CGFloat(i) + colWidth / 2
                let y = scoreToY(CGFloat(score), height: height)
                return (i, x, y, entry)
            }

        ZStack {
            Path { path in
                let midY = scoreToY(5, height: height)
                path.move(to: CGPoint(x: 0, y: midY))
                path.addLine(to: CGPoint(x: geo.size.width, y: midY))
            }
            .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
            .foregroundStyle(Color.white.opacity(0.12))

            if points.count >= 2 {
                Path { path in
                    for (i, point) in points.enumerated() {
                        if i == 0 {
                            path.move(to: CGPoint(x: point.x, y: point.y))
                        } else {
                            let prev = points[i - 1]
                            if point.index == prev.index + 1 {
                                let cp1 = CGPoint(x: (prev.x + point.x) / 2, y: prev.y)
                                let cp2 = CGPoint(x: (prev.x + point.x) / 2, y: point.y)
                                path.addCurve(
                                    to: CGPoint(x: point.x, y: point.y),
                                    control1: cp1,
                                    control2: cp2
                                )
                            } else {
                                path.move(to: CGPoint(x: point.x, y: point.y))
                            }
                        }
                    }
                }
                .stroke(Color.white.opacity(0.6),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }

            ForEach(points, id: \.index) { point in
                NavigationLink(value: point.entry) {
                    Circle()
                        .fill(moodColor(for: point.entry.moodEmoji))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                        .contentShape(Circle().scale(2))
                }
                .buttonStyle(.plain)
                .position(x: point.x, y: point.y)
            }
        }
    }

    func moodColor(for emoji: String) -> Color {
        guard let score = MoodOption.score(for: emoji) else { return Color.white.opacity(0.5) }
        switch score {
        case 8...10: return Color(hex: "#7DD8A8")
        case 6...7:  return Color(hex: "#8AB8F5")
        case 4...5:  return Color(hex: "#F5D478")
        case 2...3:  return Color(hex: "#F0A06A")
        default:     return Color(hex: "#E57373")
        }
    }
}
