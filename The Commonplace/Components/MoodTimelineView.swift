// MoodTimelineView.swift
// Commonplace
//
// Displays a 14-day mood sentiment timeline as an insight card.
// Shown in the Today tab between JournalBlockView and Captured Today.
//
// Each column represents one day:
//   - Day of week initial at top (S M T W T F S)
//   - Emoji floating above/below midline based on mood score (1-10)
//   - Thin stem connecting emoji to midline
//   - Date number at bottom (always shown, even for days with no mood)
//   - Alternating column shading for readability
//   - Dashed midline representing score 5 (neutral)
//
// Tapping an emoji navigates to that day's journal entry.
// Back/forward arrows navigate in 14-day blocks.
// Forward arrow hidden when viewing current 14 days.
//
// Mood scores sourced from MoodOption.score(for:) lookup.
// Hidden entirely when fewer than 3 mood entries exist in the window.

import SwiftUI
import SwiftData

struct MoodTimelineView: View {
    let entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    @State private var offset: Int = 0
    @State private var navigateTo: Entry? = nil

    var style: any AppThemeStyle { themeManager.style }

    private let chartHeight: CGFloat = 160
    private let minScore: CGFloat = 1
    private let maxScore: CGFloat = 10
    private let midScore: CGFloat = 5
    private let dowLabels = ["S","M","T","W","T","F","S"]

    var windowDates: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<14).reversed().map { i in
            Calendar.current.date(byAdding: .day, value: -(i + offset * 14), to: today)!
        }
    }

    var windowEntries: [Entry?] {
        windowDates.map { date in
            entries.first {
                $0.type == .journal &&
                Calendar.current.isDate($0.createdAt, inSameDayAs: date) &&
                !($0.moodEmoji.isEmpty)
            }
        }
    }

    var moodCount: Int {
        windowEntries.compactMap { $0 }.count
    }

    var dateRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: windowDates.first!)) — \(fmt.string(from: windowDates.last!))"
    }

    func scoreToY(_ score: CGFloat) -> CGFloat {
        let padding: CGFloat = 16
        let normalized = (score - minScore) / (maxScore - minScore)
        return padding + (1 - normalized) * (chartHeight - padding * 2)
    }

    var body: some View {
        if moodCount >= 3 {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.bottom, 8)
                Text(dateRangeLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(style.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
                chartArea
            }
            .padding(16)
            .background(style.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .navigationDestination(for: Entry.self) { entry in
                destinationView(for: entry)
            }
        }
    }

    // MARK: - Header

    var headerRow: some View {
        HStack {
            Text("Mood")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .textCase(.uppercase)
            Spacer()
            HStack(spacing: 4) {
                Button {
                    withAnimation { offset += 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(style.accent)
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(style.accent.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                if offset > 0 {
                    Button {
                        withAnimation { offset = max(0, offset - 1) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(style.accent)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(style.accent.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Chart

    var chartArea: some View {
        VStack(spacing: 2) {
            // Day of week row
            HStack(spacing: 0) {
                ForEach(Array(windowDates.enumerated()), id: \.offset) { i, date in
                    let dow = Calendar.current.component(.weekday, from: date) - 1
                    Text(dowLabels[dow])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(style.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            // Main chart
            GeometryReader { geo in
                let colWidth = geo.size.width / 14
                let midY = chartHeight / 2

                ZStack(alignment: .topLeading) {
                    // Alternating column backgrounds
                    HStack(spacing: 0) {
                        ForEach(0..<14, id: \.self) { i in
                            Rectangle()
                                .fill(i % 2 == 0
                                      ? style.secondaryText.opacity(0.04)
                                      : Color.clear)
                                .frame(width: colWidth)
                        }
                    }

                    // Dashed midline
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: geo.size.width, y: midY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(style.secondaryText.opacity(0.3))

                    // Emoji + stems
                    ForEach(Array(windowEntries.enumerated()), id: \.offset) { i, entry in
                        let cx = colWidth * CGFloat(i) + colWidth / 2
                        if let entry, let score = MoodOption.score(for: entry.moodEmoji) {
                            let y = scoreToY(CGFloat(score))
                            let stemTop = min(y, midY)
                            let stemHeight = max(abs(y - midY), 2)

                            // Stem
                            Rectangle()
                                .fill(style.secondaryText.opacity(0.2))
                                .frame(width: 1, height: stemHeight)
                                .position(x: cx, y: stemTop + stemHeight / 2)

                            // Emoji
                            NavigationLink(destination: destinationView(for: entry)) {
                                Text(entry.moodEmoji)
                                    .font(.system(size: 14))
                                    .position(x: cx, y: y)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: chartHeight)
            }
            .frame(height: chartHeight)

            // Date row
            HStack(spacing: 0) {
                ForEach(Array(windowDates.enumerated()), id: \.offset) { i, date in
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 9))
                        .foregroundStyle(style.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 3)
        }
    }
}
