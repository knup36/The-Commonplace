// EntryTagRow.swift
// Commonplace
//
// Shared component for displaying and editing tags and people
// across all entry detail views (EntryDetailView, LocationDetailView,
// StickyDetailView).
//
// In view mode: renders a horizontal scrolling row showing the bookmark
// indicator, people tags, and content tags separated by pipes.
//
// In edit mode: renders PersonInputView and TagInputView stacked vertically
// for input.
//
// Requires EditModeManager via @EnvironmentObject.
// Added: v2.4 — extracted from three duplicate implementations.

import SwiftUI
import SwiftData

struct EntryTagRow: View {
    @Binding var tagNames: [String]
    var isPinned: Bool
    var accentColor: Color
    var style: any AppThemeStyle
    @Query var allEntries: [Entry]

    @EnvironmentObject var editMode: EditModeManager

    var existingTagsSortedByFrequency: [String] {
            let allNames = allEntries.flatMap { $0.tagNames }.filter { !$0.hasPrefix("@") }
            let counts = Dictionary(allNames.map { ($0, 1) }, uniquingKeysWith: +)
            let result = counts.sorted { $0.value > $1.value }.map { $0.key }
            print("DEBUG existingTagsSortedByFrequency: \(result.count) tags, allEntries: \(allEntries.count)")
            return result
        }

    var personFrequencyCounts: [String: Int] {
        Dictionary(
            allEntries.flatMap { $0.tagNames.filter { $0.hasPrefix("@") } }
                .map { (String($0.dropFirst()), 1) },
            uniquingKeysWith: +
        )
    }

    var hasPeople: Bool { tagNames.contains { $0.hasPrefix("@") } }
    var hasTags: Bool   { tagNames.contains { !$0.hasPrefix("@") } }

    var body: some View {
        if editMode.isEditing {
                    PersonInputView(tags: $tagNames, personFrequencyCounts: personFrequencyCounts, accentColor: accentColor, style: style)
                    TagInputView(tags: $tagNames, existingTagsSortedByFrequency: existingTagsSortedByFrequency, accentColor: accentColor, style: style)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if isPinned {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(accentColor)
                                if hasPeople || hasTags {
                                    pipe
                                }
                            }
                            if hasPeople {
                                PersonInputView(tags: $tagNames, personFrequencyCounts: personFrequencyCounts, accentColor: accentColor, style: style)
                                if hasTags {
                                    pipe
                                }
                            }
                            if hasTags {
                                TagInputView(tags: $tagNames, existingTagsSortedByFrequency: existingTagsSortedByFrequency, accentColor: accentColor, style: style)
                            }
                        }
                    }
                }
    }

    var pipe: some View {
        Text("|")
            .font(.system(size: 18))
            .foregroundStyle(accentColor.opacity(0.3))
    }
}
