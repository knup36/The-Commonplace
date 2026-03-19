import SwiftUI
import SwiftData

// MARK: - SearchView
// Spotlight-style global search across all entries, collections, and tags.
// Promoted to its own tab for quick access from anywhere in the app.
// Screen: Search tab (3rd tab)

struct SearchView: View {
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    var style: any AppThemeStyle { themeManager.style }

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                Text("Search coming soon")
                    .font(style.body)
                    .foregroundStyle(style.secondaryText)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(style.background.ignoresSafeArea())
            .navigationTitle(style.usesSerifFonts ? "" : "Search")
            .navigationBarTitleDisplayMode(style.usesSerifFonts ? .inline : .large)
            .toolbar {
                if style.usesSerifFonts {
                    ToolbarItem(placement: .principal) {
                        Text("Search")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundStyle(style.primaryText)
                    }
                }
            }
        }
    }
}
