// ChroniclesReorderView.swift
// Commonplace
//
// Sheet presented from ChroniclesView that allows the user to drag-reorder
// the Chronicles cards. Order is persisted via AppStorage and reflected
// immediately in ChroniclesView on dismiss.
//
// Card metadata (title, icon) is defined here as the single source of truth
// for display names shown in the reorder list.

import SwiftUI

struct ChroniclesReorderView: View {
    @Binding var cardOrder: [String]
    @Environment(\.dismiss) private var dismiss

    // Display metadata for each card ID
    static let cardMeta: [String: (title: String, icon: String)] = [
        "dogEars":       (title: "Dog-Ears",      icon: "bookmark.fill"),
        "onThisDay":     (title: "On This Day",    icon: "calendar"),
        "mood":          (title: "Mood Timeline",  icon: "chart.line.uptrend.xyaxis"),
        "stats":         (title: "Stats",          icon: "number"),
        "watchTimeline": (title: "Watch Timeline", icon: "film.stack"),
        "habitPatterns": (title: "Habit Patterns", icon: "checkmark.circle")
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(cardOrder, id: \.self) { cardID in
                    let meta = Self.cardMeta[cardID]
                    HStack(spacing: 12) {
                        Image(systemName: meta?.icon ?? "square")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ChroniclesTheme.accentAmber)
                            .frame(width: 20)
                        Text(meta?.title ?? cardID)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .padding(.vertical, 4)
                }
                .onMove { from, to in
                    cardOrder.move(fromOffsets: from, toOffset: to)
                }
            }
            .navigationTitle("Reorder Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }
}
