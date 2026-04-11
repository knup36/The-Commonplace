// ScrapbookBackground.swift
// Commonplace
//
// Reusable scrapbook paper background.
// Warm amber cream color with a subtle dot grid pattern — like a Leuchtturm notebook.
// Used as the feed background in Scrapbook mode.
//
// Usage:
//   .background(ScrapbookBackground())
//
// All visual constants live in ScrapbookTheme — edit there to affect all scrapbook views.

import SwiftUI

struct ScrapbookBackground: View {

    var body: some View {
        ScrapbookTheme.paperColor
            .overlay(DotGrid())
            .ignoresSafeArea()
    }
}

// MARK: - Dot Grid

private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing = ScrapbookTheme.dotSpacing
            let radius  = ScrapbookTheme.dotRadius
            let color   = ScrapbookTheme.dotColor.opacity(ScrapbookTheme.dotOpacity)

            var y: CGFloat = spacing
            while y < size.height {
                var x: CGFloat = spacing
                while x < size.width {
                    let rect = CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}
