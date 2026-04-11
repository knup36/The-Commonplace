// MoodTimelineCard.swift
// Commonplace
//
// Chronicles card wrapping the existing MoodTimelineView component.
// Shows 14-day mood sentiment chart with emoji data points.
// Empty state shown when no journal entries exist yet.

import SwiftUI

struct MoodTimelineCard: View {
    let entries: [Entry]
    var style: any AppThemeStyle

    var journalEntries: [Entry] {
        entries.filter { $0.type == .journal }
    }

    var body: some View {
        ChroniclesCardContainer(title: "Mood", icon: "waveform.path.ecg") {
            if journalEntries.isEmpty {
                Text("Start journaling to see your mood patterns over time.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                MoodTimelineView(entries: entries)
            }
        }
    }
}
