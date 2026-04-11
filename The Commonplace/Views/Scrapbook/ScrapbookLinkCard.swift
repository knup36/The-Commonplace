// ScrapbookLinkCard.swift
// Commonplace
//
// Scrapbook feed card for .link entries.
// Renders as a newspaper/magazine clipping — off-white newsprint,
// left-aligned serif text, source domain in small caps.
//
// Layout:
//   - Source domain in small caps at top (with favicon if available)
//   - Thin rule below source
//   - Title in large serif, left aligned, up to 3 lines
//   - Description or note text below, smaller, muted
//   - Date right-aligned at bottom
//
// Slight rotation seeded from entry UUID — range -3 to +3 degrees.
// Clippings sit flatter than Polaroids — less rotation feels right.
// No tape — clippings are pasted directly to the page.

import SwiftUI

struct ScrapbookLinkCard: View {
    let entry: Entry

    /// Deterministic rotation seeded from entry UUID
    var rotation: Double {
        let hash = abs(entry.id.uuidString.hashValue)
        let normalized = Double(hash % 600) / 100.0
        return normalized - 3.0
    }

    var sourceDomain: String {
        guard let urlString = entry.url,
              let url = URL(string: urlString),
              let host = url.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "").uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Source domain + favicon
            HStack(spacing: 6) {
                if let faviconPath = entry.faviconPath,
                   let data = MediaFileManager.load(path: faviconPath),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 12, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                if !sourceDomain.isEmpty {
                    Text(sourceDomain)
                        .font(ScrapbookTheme.captionFont(size: 9))
                        .kerning(1.5)
                        .foregroundStyle(ScrapbookTheme.inkTertiary)
                }
                Spacer()
            }
            .padding(.bottom, 8)

            // Thin rule
            Rectangle()
                .fill(ScrapbookTheme.inkDecorative.opacity(0.3))
                .frame(height: 0.5)
                .padding(.bottom, 10)

            // Title
            if let title = entry.linkTitle, !title.isEmpty {
                Text(title)
                    .font(ScrapbookTheme.titleFont(size: 18))
                    .foregroundStyle(ScrapbookTheme.inkPrimary)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .padding(.bottom, 8)
            }

            // Description or note
            let bodyText = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(ScrapbookTheme.bodyFont(size: 13))
                    .foregroundStyle(ScrapbookTheme.inkSecondary)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .padding(.bottom, 10)
            }

            Spacer(minLength: 8)

            // Date
            Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(ScrapbookTheme.captionFont(size: 9))
                .kerning(0.8)
                .foregroundStyle(ScrapbookTheme.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(width: 280, height: 200)
        .background(Color(red: 0.95, green: 0.93, blue: 0.87))
        .clipShape(RoundedRectangle(cornerRadius: ScrapbookTheme.cardCornerRadius))
        .shadow(color: ScrapbookTheme.cardShadowColor, radius: ScrapbookTheme.cardShadowRadius, x: 0, y: ScrapbookTheme.cardShadowY)
        .rotationEffect(.degrees(rotation))
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}
