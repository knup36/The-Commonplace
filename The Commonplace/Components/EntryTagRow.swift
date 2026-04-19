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

struct EntryTagRow: View {
    @Binding var tagNames: [String]
    var isPinned: Bool
    var accentColor: Color
    var style: any AppThemeStyle

    @EnvironmentObject var editMode: EditModeManager

    var hasPeople: Bool { tagNames.contains { $0.hasPrefix("@") } }
    var hasTags: Bool   { tagNames.contains { !$0.hasPrefix("@") } }

    var body: some View {
        if editMode.isEditing {
            PersonInputView(tags: $tagNames, accentColor: accentColor, style: style)
            TagInputView(tags: $tagNames, accentColor: accentColor, style: style)
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
                        PersonInputView(tags: $tagNames, accentColor: accentColor, style: style)
                        if hasTags {
                            pipe
                        }
                    }
                    if hasTags {
                        TagInputView(tags: $tagNames, accentColor: accentColor, style: style)
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
