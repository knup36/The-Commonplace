// MoodTimelineCard.swift
// Commonplace
//
// Chronicles card showing a mood sentiment line graph as a horizontally
// scrollable timeline. Each day occupies a fixed-width column; the strip
// is capped to a rolling window (default 6 months) for performance.
//
// Interaction: drag left/right to move through time. Most recent day is
// anchored at the right edge on first appearance. Tapping a dot navigates
// to that journal entry. A "Load Earlier" button at the left edge expands
// the window by 6 months at a time, only shown when older data exists.
//
// Updated v2.6 — replaced 7-day paged window + arrow buttons with a
//               continuous horizontal scroll; 6-month default window
//               with on-demand backdating in 6-month increments.

import SwiftUI

struct MoodTimelineCard: View {
    let journalEntries: [Entry]
    var style: any AppThemeStyle

    @EnvironmentObject var themeManager: ThemeManager

    // How many months back the current window extends
    @State private var loadedMonths: Int = 6

    // Fixed column width — ~14 columns visible on a standard screen
    private let colWidth: CGFloat = 28
    private let chartHeight: CGFloat = 140
    private let minScore: CGFloat = 1
    private let maxScore: CGFloat = 10
    private let dowLabels = ["S","M","T","W","T","F","S"]

    // All mood entries sorted oldest → newest
    var moodEntries: [(date: Date, entry: Entry)] {
        journalEntries
            .filter { !$0.moodEmoji.isEmpty }
            .sorted { $0.createdAt < $1.createdAt }
            .map { (Calendar.current.startOfDay(for: $0.createdAt), $0) }
    }

    var moodCount: Int { moodEntries.count }

    // The earliest date in the current window
    var windowStart: Date {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .month, value: -loadedMonths, to: today)!
    }

    // Whether there are mood entries older than the current window
    var hasEarlierData: Bool {
        moodEntries.first.map { $0.date < windowStart } ?? false
    }

    // Days within the current window, oldest → newest
    var allDays: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        var days: [Date] = []
        var cursor = windowStart
        while cursor <= today {
            days.append(cursor)
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
        }
        return days
    }

    var body: some View {
        ChroniclesCardContainer(title: "Mood", icon: "waveform.path.ecg", cardID: "mood", background: .parchment) {
            if moodCount < 2 {
                Text("Start journaling to see your mood patterns over time.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(Color.white.opacity(0.4))
            } else {
                let buttonWidth: CGFloat = hasEarlierData ? 80 : 0
                let chartWidth = colWidth * CGFloat(allDays.count)
                let totalWidth = buttonWidth + chartWidth

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {

                        // Chart row — Load Earlier button sits to the left of the timeline
                        HStack(alignment: .top, spacing: 0) {
                            if hasEarlierData {
                                Button {
                                    loadedMonths += 6
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "chevron.left.2")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                        Text("Load\nEarlier")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(width: buttonWidth, height: chartHeight)
                                    .overlay(
                                        Rectangle()
                                            .fill(Color.white.opacity(0.04))
                                            .frame(width: 1),
                                        alignment: .trailing
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            lineChart(totalWidth: chartWidth)
                                .frame(width: chartWidth, height: chartHeight)
                        }

                        // Day-of-week labels aligned under the chart only
                        HStack(spacing: 0) {
                            if hasEarlierData {
                                Spacer().frame(width: buttonWidth)
                            }
                            HStack(spacing: 0) {
                                ForEach(Array(allDays.enumerated()), id: \.offset) { _, date in
                                    let dow = Calendar.current.component(.weekday, from: date) - 1
                                    Text(dowLabels[dow])
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(
                                            isToday(date)
                                            ? Color.white.opacity(0.8)
                                            : Color.white.opacity(0.3)
                                        )
                                        .frame(width: colWidth)
                                }
                            }
                        }
                    }
                    .frame(width: totalWidth)
                }
                .defaultScrollAnchor(.trailing)
            }
        }
    }

    // MARK: - Line Chart

    @ViewBuilder
    func lineChart(totalWidth: CGFloat) -> some View {
        let height = chartHeight

        let points: [(index: Int, x: CGFloat, y: CGFloat, entry: Entry)] = allDays
            .enumerated()
            .compactMap { i, date in
                guard let match = moodEntries.first(where: {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                }),
                let score = MoodOption.score(for: match.entry.moodEmoji)
                else { return nil }
                let x = colWidth * CGFloat(i) + colWidth / 2
                let y = scoreToY(CGFloat(score), height: height)
                return (i, x, y, match.entry)
            }

        ZStack {
            // Midline
            Path { path in
                let midY = scoreToY(5, height: height)
                path.move(to: CGPoint(x: 0, y: midY))
                path.addLine(to: CGPoint(x: totalWidth, y: midY))
            }
            .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
            .foregroundStyle(Color.white.opacity(0.12))

            // Today marker
            if let todayIndex = allDays.firstIndex(where: { isToday($0) }) {
                let x = colWidth * CGFloat(todayIndex) + colWidth / 2
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }

            // Connecting curve
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

            // Mood dots
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

    // MARK: - Helpers

    func scoreToY(_ score: CGFloat, height: CGFloat) -> CGFloat {
        let padding: CGFloat = 8
        let normalized = (score - minScore) / (maxScore - minScore)
        return padding + (1 - normalized) * (height - padding * 2)
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
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
