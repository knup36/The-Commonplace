// WeeklyReviewEntryListView.swift
// Commonplace
//
// Filtered entry list shown when tapping an entry type row
// in the Weekly Review glance section.
// Shows all entries of a specific type captured during the review week.

import SwiftUI

struct WeeklyReviewEntryListView: View {
    let entries: [Entry]
    let title: String
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    NavigationLink(destination: destinationView(for: entry)) {
                        EntryRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .padding(.top, 8)
        }
        .background(WeeklyReviewTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
