// DogEarsCard.swift
// Commonplace
//
// Chronicles card surfacing entries that need attention —
// stickies with unchecked items, and entries tagged "later".
// Receives pre-filtered arrays from ChroniclesView.
//
// Updated v2.4 — pre-filtered data, compact card strips,
//               peek affordance, dynamic 1-2 row later grid.

import SwiftUI

struct DogEarsCard: View {
    let stickyEntries: [Entry]
    let laterEntries: [Entry]
    var style: any AppThemeStyle

    @EnvironmentObject var themeManager: ThemeManager

    var hasContent: Bool { !stickyEntries.isEmpty || !laterEntries.isEmpty }

    var body: some View {
        if !hasContent { return AnyView(EmptyView()) }
        return AnyView(
            ChroniclesCardContainer(title: "Dog-Ears", icon: "bookmark.fill", cardID: "dogEars", background: .parchment) {
                VStack(alignment: .leading, spacing: 0) {

                    if !stickyEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lists")
                                .font(style.typeCaption)
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.leading, 2)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(stickyEntries) { entry in
                                        NavigationLink(value: entry) {
                                            CompactEntryCard(entry: entry, style: style)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    if stickyEntries.count > 5 {
                                        seeMoreCard(count: stickyEntries.count - 5)
                                    }
                                }
                                .padding(.trailing, 32)
                            }
                            .padding(.trailing, -16)
                        }
                    }

                    if !stickyEntries.isEmpty && !laterEntries.isEmpty {
                        Divider()
                            .overlay(Color.white.opacity(0.1))
                            .padding(.vertical, 12)
                    }

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
                                        NavigationLink(value: entry) {
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

    func seeMoreCard(count: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
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
