import SwiftUI

// MARK: - HomeView
// Personal dashboard — the main entry point of the app.
// Surfaces pinned collections, recent entries, outstanding stickies,
// habit streaks, calendar, and quick capture shortcuts.
// Screen: Home tab (leftmost tab)

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    var style: any AppThemeStyle { themeManager.style }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Home")
                        .font(style.usesSerifFonts
                              ? .system(size: 34, weight: .bold, design: .serif)
                              : .largeTitle.bold())
                        .foregroundStyle(style.primaryText)
                        .padding(.horizontal)
                        .padding(.top, 4)

                    Text("Home view coming soon.")
                        .font(style.body)
                        .foregroundStyle(style.secondaryText)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical)
            }
            .background(style.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
