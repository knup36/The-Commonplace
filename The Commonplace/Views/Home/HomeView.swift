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
            ZStack {
                style.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(style.surface.opacity(0.3), lineWidth: 0.5)
                            .frame(width: 180, height: 180)
                        Circle()
                            .stroke(style.surface.opacity(0.5), lineWidth: 0.5)
                            .frame(width: 140, height: 140)
                        Circle()
                            .stroke(style.surface.opacity(0.3), lineWidth: 0.5)
                            .frame(width: 100, height: 100)
                        Circle()
                            .fill(style.surface.opacity(0.6))
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(style.surface)
                            .frame(width: 56, height: 56)
                        Image(systemName: "house.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(style.accent.opacity(0.7))
                    }
                    Text("Home")
                        .font(style.usesSerifFonts
                              ? .system(.title2, design: .serif)
                              : .title2)
                        .fontWeight(.bold)
                        .foregroundStyle(style.primaryText)
                    Text("COMING SOON")
                        .font(.system(size: 11, weight: .medium))
                        .kerning(2)
                        .foregroundStyle(style.tertiaryText)
                    HStack(spacing: 8) {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(style.accent.opacity(0.4))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
        }
    }
}
