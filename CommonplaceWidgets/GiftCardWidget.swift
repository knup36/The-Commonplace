// GiftCardWidget.swift
// CommonplaceWidgets
//
// Small widget showing the most recently fired Gift Card.
// Tapping opens Commonplace to the Chronicles tab.
//
// Data is read from the App Group container via GiftCardSnapshotStore.
// The main app writes to this container via GiftCardSnapshotStore.save()
// whenever a card fires in GiftCardService.
//
// Add this file to the CommonplaceWidgets target only.

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct GiftCardEntry: TimelineEntry {
    let date: Date
    let snapshot: GiftCardSnapshot?

    static var placeholder: GiftCardEntry {
            GiftCardEntry(
                date: Date(),
                snapshot: GiftCardSnapshot(
                    title: "Still on your list?",
                    message: "Dune has been on your watchlist for 3 months.",
                    icon: "bookmark",
                    firedAt: Date(),
                    isEmpty: false,
                    thumbnailPath: nil
                )
            )
        }
}

// MARK: - Timeline Provider

struct GiftCardProvider: TimelineProvider {
    func placeholder(in context: Context) -> GiftCardEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (GiftCardEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GiftCardEntry>) -> Void) {
        let current = entry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [current], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func entry() -> GiftCardEntry {
        let snapshot = GiftCardSnapshotStore.load()
        return GiftCardEntry(date: Date(), snapshot: snapshot)
    }
}

// MARK: - Widget View

struct GiftCardWidgetView: View {
    var entry: GiftCardEntry

    var body: some View {
        if let snapshot = entry.snapshot, !snapshot.isEmpty {
                    activeCardView(snapshot: snapshot)
                        .widgetURL(URL(string: "commonplace://chronicles"))
                } else {
                    emptyView
                        .widgetURL(URL(string: "commonplace://chronicles"))
                }
    }

    // MARK: - Active Card

    func activeCardView(snapshot: GiftCardSnapshot) -> some View {
            HStack(alignment: .top, spacing: 10) {
                // Thumbnail
                if let filename = snapshot.thumbnailPath,
                   let data = GiftCardSnapshotStore.loadThumbnail(filename: filename),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: snapshot.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Gift Card")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                    }

                    Spacer()

                    Text(snapshot.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)

                    Text(snapshot.message)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }

    // MARK: - Empty State

    var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No cards yet")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct GiftCardWidget: Widget {
    let kind: String = "GiftCardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GiftCardProvider()) { entry in
                    GiftCardWidgetView(entry: entry)
                        .containerBackground(
                            LinearGradient(
                                colors: [Color(hex: "#4A4A52"), Color(hex: "#32323A")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            for: .widget
                        )
                }
        .configurationDisplayName("Gift Card")
        .description("See your latest Commonplace gift card.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    GiftCardWidget()
} timeline: {
    GiftCardEntry.placeholder
}
