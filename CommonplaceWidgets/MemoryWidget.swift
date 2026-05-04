// MemoryWidget.swift
// CommonplaceWidgets
//
// Small widget surfacing a random past entry from your archive.
// Refreshes once per day when the app is opened.
//
// Photo entries show full-bleed image with gradient overlay.
// All other entries show icon, title/text, and time ago.
// Tapping opens Commonplace to the Feed tab.
//
// Add this file to the CommonplaceWidgets target only.

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct MemoryEntry: TimelineEntry {
    let date: Date
    let snapshot: MemorySnapshot?

    static var placeholder: MemoryEntry {
        MemoryEntry(
            date: Date(),
            snapshot: MemorySnapshot(
                id: "1",
                type: "text",
                title: "Started thinking about the nature of memory and how we archive our lives.",
                text: "Started thinking about the nature of memory and how we archive our lives.",
                icon: "text.alignleft",
                accentHex: "#B8A888",
                createdAt: Date().addingTimeInterval(-60 * 86400),
                imagePath: nil
            )
        )
    }
}

// MARK: - Timeline Provider

struct MemoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoryEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoryEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoryEntry>) -> Void) {
        let current = entry()
        // Refresh once per day — main app writes new snapshot on launch
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        let timeline = Timeline(entries: [current], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func entry() -> MemoryEntry {
        let snapshot = MemorySnapshotStore.load()
        return MemoryEntry(date: Date(), snapshot: snapshot)
    }
}

// MARK: - Widget View

struct MemoryWidgetView: View {
    var entry: MemoryEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            if snapshot.type == "photo", let filename = snapshot.imagePath,
               let data = MemorySnapshotStore.loadImage(filename: filename),
               let uiImage = UIImage(data: data) {
                photoView(image: uiImage, snapshot: snapshot)
            } else {
                textView(snapshot: snapshot)
            }
        } else {
            emptyView
        }
    }

    // MARK: - Photo View

    func photoView(image: UIImage, snapshot: MemorySnapshot) -> some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text("From your archive")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text(timeAgo(snapshot.createdAt))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
    }

    // MARK: - Text View

    func textView(snapshot: MemorySnapshot) -> some View {
        let accent = Color(hex: snapshot.accentHex)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: snapshot.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(accent)
                Text("From your archive")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            if let title = snapshot.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(4)
            } else if !snapshot.text.isEmpty {
                Text(snapshot.text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(4)
            }

            Text(timeAgo(snapshot.createdAt))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(1)
    }

    // MARK: - Empty State

    var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("Check back soon")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Time Ago

    func timeAgo(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 { return "\(days)d ago" }
        let weeks = days / 7
        if weeks < 5 { return "\(weeks)w ago" }
        let months = days / 30
        if months < 12 { return "\(months)mo ago" }
        return "\(months / 12)y ago"
    }
}

// MARK: - Widget

struct MemoryWidget: Widget {
    let kind: String = "MemoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoryProvider()) { entry in
            MemoryWidgetView(entry: entry)
                .widgetURL(URL(string: "commonplace://feed"))
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Memory")
        .description("Rediscover something you captured in the past.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    MemoryWidget()
} timeline: {
    MemoryEntry.placeholder
}
