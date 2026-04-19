// DogEarsCard.swift
// Commonplace
//
// Chronicles card surfacing entries that need attention —
// stickies with unchecked items, and entries tagged "later".
//
// Two separate horizontal strips:
//   1. Stickies with unchecked items — single row
//   2. Later-tagged entries — two-row LazyHGrid
//
// Both strips use a negative trailing padding trick to let the last
// card peek out, signalling to the user that there is more to scroll.
//
// Updated v2.4 — separated strips, peek affordance, 2-row later grid.

import SwiftUI

struct DogEarsCard: View {
    let entries: [Entry]
    var style: any AppThemeStyle
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var overdueStickies: [Entry] {
        entries.filter { entry in
            guard entry.type == .sticky else { return false }
            let unchecked = entry.stickyItems.filter { raw in
                let id = raw.components(separatedBy: "::").first ?? ""
                return !entry.stickyChecked.contains(id)
            }
            return !unchecked.isEmpty
        }
    }
    
    var laterEntries: [Entry] {
        entries.filter { $0.tagNames.contains("later") }
    }
    
    var hasContent: Bool {
        !overdueStickies.isEmpty || !laterEntries.isEmpty
    }
    
    var body: some View {
        if !hasContent { return AnyView(EmptyView()) }
        return AnyView(
            ChroniclesCardContainer(title: "Dog-Ears", icon: "bookmark.fill", background: .parchment) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // MARK: - Stickies strip
                    if !overdueStickies.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lists")
                                .font(style.typeCaption)
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.leading, 2)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(overdueStickies) { entry in
                                        NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                                            CompactEntryCard(entry: entry, style: style)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    if overdueStickies.count > 5 {
                                        seeMoreCard(count: overdueStickies.count - 5)
                                    }
                                }
                                .padding(.trailing, 32)
                            }
                            .padding(.trailing, -16)
                        }
                    }
                    
                    // MARK: - Divider
                    if !overdueStickies.isEmpty && !laterEntries.isEmpty {
                        Divider()
                            .overlay(Color.white.opacity(0.1))
                            .padding(.vertical, 12)
                    }
                    
                    // MARK: - Later entries strip (2-row grid)
                    if !laterEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Later")
                                .font(style.typeCaption)
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.leading, 2)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHGrid(
                                    rows: laterEntries.count <= 5
                                    ? [GridItem(.fixed(80), spacing: 10)]
                                    : [GridItem(.fixed(80), spacing: 10),
                                       GridItem(.fixed(80), spacing: 10)],
                                    spacing: 10
                                ) {
                                    ForEach(laterEntries) { entry in
                                        NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                                            CompactEntryCard(entry: entry, style: style)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    if laterEntries.count > 10 {
                                        seeMoreCard(count: laterEntries.count - 10)
                                    }
                                }
                                .padding(.trailing, 32)
                            }
                            .padding(.trailing, -16)
                        }
                    }
                }
            }
        )
    }
    
    // MARK: - See More Card
    
    func seeMoreCard(count: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            VStack(spacing: 4) {
                Text("+\(count)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
                Text("more")
                    .font(style.typeCaption)
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
        .frame(width: 80, height: 80)
    }
}
