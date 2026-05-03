// RecentEntriesWidget.swift
// CommonplaceWidgets
//
// Recent Entries widget for Commonplace.
// Shows the most recently captured entries across three sizes:
//
//   Small  — single most recent entry: icon, text preview, time ago
//   Medium — 2-3 most recent entries in a compact list
//   Large  — 5-6 most recent entries in a fuller list
//
// Data is read from the App Group container via WidgetSnapshotStore.
// The main app writes to this container via WidgetDataStore whenever
// an entry is created, updated, or deleted.
//
// Tapping the widget opens Commonplace to the Feed tab.
//
// Add this file to the CommonplaceWidgets target only.

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct RecentEntriesEntry: TimelineEntry {
    let date: Date
    let snapshots: [WidgetEntrySnapshot]
    
    /// Placeholder data shown while widget loads
    static var placeholder: RecentEntriesEntry {
            RecentEntriesEntry(
                date: Date(),
                snapshots: [
                    WidgetEntrySnapshot(id: "1", type: "text",     text: "Started reading a fascinating book about the history of maps.", title: nil,                       createdAt: Date(),                             icon: "text.alignleft",    accentHex: "#A0A0A0"),
                    WidgetEntrySnapshot(id: "2", type: "music",    text: "",                                                               title: "Radiohead — OK Computer", createdAt: Date().addingTimeInterval(-3600),   icon: "music.note",        accentHex: "#E57373"),
                    WidgetEntrySnapshot(id: "3", type: "location", text: "",                                                               title: "Griffith Observatory",    createdAt: Date().addingTimeInterval(-7200),   icon: "mappin.circle.fill", accentHex: "#66BB6A"),
                    WidgetEntrySnapshot(id: "4", type: "link",     text: "",                                                               title: "The Art of Noticing",     createdAt: Date().addingTimeInterval(-10800),  icon: "link",              accentHex: "#64B5F6"),
                    WidgetEntrySnapshot(id: "5", type: "photo",    text: "",                                                               title: nil,                        createdAt: Date().addingTimeInterval(-14400),  icon: "photo.fill",        accentHex: "#E57373"),

                ]
            )
        }
}

// MARK: - Timeline Provider

struct RecentEntriesProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> RecentEntriesEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RecentEntriesEntry) -> Void) {
        completion(entry(for: context))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntriesEntry>) -> Void) {
        let current = entry(for: context)
        // Refresh every 15 minutes as a fallback — main app triggers immediate
        // refresh via WidgetCenter.shared.reloadAllTimelines() on every entry change
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [current], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func entry(for context: Context) -> RecentEntriesEntry {
        let payload = WidgetSnapshotStore.load()
        return RecentEntriesEntry(
            date: payload?.updatedAt ?? Date(),
            snapshots: payload?.snapshots ?? []
        )
    }
}

// MARK: - Widget Entry View

struct RecentEntriesEntryView: View {
    var entry: RecentEntriesEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
                case .systemSmall:  smallView
                case .systemMedium: mediumView
                default:            smallView
                }
    }
    
    // MARK: - Small (1 entry)
    
    var smallView: some View {
        Group {
            if let snapshot = entry.snapshots.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: snapshot.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(timeAgo(snapshot.createdAt))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    if let title = snapshot.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    } else if !snapshot.text.isEmpty {
                        Text(snapshot.text)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(4)
                    } else {
                        Text(snapshot.type.capitalized)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(1)
            } else {
                emptyState
            }
        }
    }
    
    // MARK: - Medium (3 entries)
    
    var mediumView: some View {
        Group {
            if entry.snapshots.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entry.snapshots.prefix(4).enumerated()), id: \.element.id) { i, snapshot in
                                            entryRow(snapshot: snapshot)
                                            if i < min(3, entry.snapshots.prefix(4).count - 1) {
                                                Divider().opacity(0.3)
                                            }
                                        }
                }
                .padding(1)
            }
        }
    }
    
    // MARK: - Subviews
    
    var widgetHeader: some View {
        HStack {
            Text("Commonplace")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(timeAgo(entry.snapshots.first?.createdAt ?? Date()))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 8)
    }
    
    func entryRow(snapshot: WidgetEntrySnapshot) -> some View {
            let accent = Color(hex: snapshot.accentHex)
            return HStack(spacing: 10) {
                Image(systemName: snapshot.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 16)
            
                VStack(alignment: .leading, spacing: 1) {
                                if let title = snapshot.title, !title.isEmpty {
                                    Text(title)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(accent)
                                        .lineLimit(1)
                                } else if !snapshot.text.isEmpty {
                                    Text(snapshot.text)
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundStyle(accent)
                                        .lineLimit(1)
                                } else {
                                    Text(snapshot.type.capitalized)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(accent)
                                        .lineLimit(1)
                                }
                            }
            
            Spacer()
            
            Text(timeAgo(snapshot.createdAt))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 7)
    }
    
    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No entries yet")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Time Ago Helper
    
    func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Widget

struct RecentEntriesWidget: Widget {
    let kind: String = "RecentEntriesWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentEntriesProvider()) { entry in
            RecentEntriesEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Recent Entries")
        .description("See your most recently captured pages.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    RecentEntriesWidget()
} timeline: {
    RecentEntriesEntry.placeholder
}

#Preview(as: .systemMedium) {
    RecentEntriesWidget()
} timeline: {
    RecentEntriesEntry.placeholder
}

#Preview(as: .systemLarge) {
    RecentEntriesWidget()
} timeline: {
    RecentEntriesEntry.placeholder
}
