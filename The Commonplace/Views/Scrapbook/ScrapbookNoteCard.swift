// ScrapbookNoteCard.swift
// Commonplace
//
// Scrapbook feed card for .text (Thought) entries.
// Floating serif text, centered, on the cream paper background.
// No container, no border — just words on paper.
//
// Layout:
//   - Title in large italic serif, centered
//   - Body in smaller serif below, centered, muted
//   - Thin decorative divider between title and body if both exist
//   - Date centered below in small caps
//
// Width: 85% of screen width, centered with generous margins.
// No rotation — notes are calm and settled on the page.

import SwiftUI

struct ScrapbookNoteCard: View {
    let entry: Entry
    
    private var inkColor: Color { ScrapbookTheme.inkPrimary }
        private var mutedColor: Color { ScrapbookTheme.inkSecondary }
        private var subtleColor: Color { ScrapbookTheme.inkDecorative }
    
    var titleText: String {
        let parts = entry.text.components(separatedBy: "\n")
        return parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    var bodyText: String {
        let parts = entry.text.components(separatedBy: "\n")
        return parts.dropFirst()
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Title
                if !titleText.isEmpty {
                    Text(titleText)
                                            .font(ScrapbookTheme.titleFont(size: 22))
                        .italic()
                        .foregroundStyle(inkColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                // Divider — only if both title and body exist
                if !titleText.isEmpty && !bodyText.isEmpty {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(subtleColor.opacity(0.4))
                            .frame(height: 0.5)
                        Text("✦")
                            .font(.system(size: 8))
                            .foregroundStyle(subtleColor.opacity(0.5))
                        Rectangle()
                            .fill(subtleColor.opacity(0.4))
                            .frame(height: 0.5)
                    }
                    .padding(.horizontal, 24)
                }
                
                // Body
                if !bodyText.isEmpty {
                    Text(bodyText)
                                            .font(ScrapbookTheme.bodyFont(size: 16))
                        .foregroundStyle(mutedColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .lineLimit(6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            
            // Date
            Text(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))
                            .font(ScrapbookTheme.captionFont(size: 10))
                .kerning(1.2)
                .foregroundStyle(ScrapbookTheme.inkTertiary)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
    }
}
