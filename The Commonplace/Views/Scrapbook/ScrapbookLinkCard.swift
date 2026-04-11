// ScrapbookLinkCard.swift
// Commonplace
//
// Scrapbook feed card for .link entries.
// Renders as a newspaper/magazine clipping — off-white newsprint,
// left-aligned serif text, source domain in small caps.
//
// Layout:
//   - Source domain + favicon left, date right — on same line
//   - Thin rule below
//   - Thumbnail image full width (if available)
//   - Thin rule below image
//   - Title in large serif, left aligned, up to 3 lines
//   - Description or note text below, smaller, muted
//
// No rotation — clippings sit flat and deliberate on the page.
// Ragged edges via RaggedEdgeShape for authentic torn paper look.
// Random left/center/right layout seeded from UUID.

import SwiftUI

struct ScrapbookLinkCard: View {
    let entry: Entry

    var linkLayoutSeed: Int { abs(entry.id.uuidString.hashValue) % 3 }

    var linkAlignment: Alignment {
        switch linkLayoutSeed {
        case 0: return .leading
        case 1: return .trailing
        default: return .center
        }
    }

    var linkLeadingPadding: CGFloat {
        switch linkLayoutSeed {
        case 0: return 8
        case 1: return 48
        default: return 16
        }
    }

    var linkTrailingPadding: CGFloat {
        switch linkLayoutSeed {
        case 0: return 48
        case 1: return 8
        default: return 16
        }
    }

    var sourceDomain: String {
        guard let urlString = entry.url,
              let url = URL(string: urlString),
              let host = url.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "").uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header — source + date on same line
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
                Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(ScrapbookTheme.captionFont(size: 9))
                    .kerning(0.8)
                    .foregroundStyle(ScrapbookTheme.inkTertiary)
            }
            .padding(.bottom, 8)

            // Thin rule
            Rectangle()
                .fill(ScrapbookTheme.inkDecorative.opacity(0.3))
                .frame(height: 0.5)

            // Thumbnail image
            if let previewPath = entry.previewImagePath,
               let data = MediaFileManager.load(path: previewPath),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipped()

                Rectangle()
                    .fill(ScrapbookTheme.inkDecorative.opacity(0.3))
                    .frame(height: 0.5)
            }

            // Title
            if let title = entry.linkTitle, !title.isEmpty {
                Text(title)
                    .font(ScrapbookTheme.titleFont(size: 17))
                    .foregroundStyle(ScrapbookTheme.inkPrimary)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
            }

            // Description or note
            let bodyText = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(ScrapbookTheme.bodyFont(size: 12))
                    .foregroundStyle(ScrapbookTheme.inkSecondary)
                    .lineSpacing(2)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(Color(red: 0.95, green: 0.93, blue: 0.87))
        .clipShape(RaggedEdgeShape(seed: entry.id.uuidString))
        .shadow(color: ScrapbookTheme.cardShadowColor, radius: ScrapbookTheme.cardShadowRadius, x: 0, y: ScrapbookTheme.cardShadowY)
        .padding(.vertical, 16)
        .padding(.leading, linkLeadingPadding)
        .padding(.trailing, linkTrailingPadding)
        .frame(maxWidth: .infinity, alignment: linkAlignment)
    }
}

// MARK: - Ragged Edge Shape

struct RaggedEdgeShape: Shape {
    let seed: String
    let steps = 12
    let raggedAmount: CGFloat = 4.0

    func offsets(count: Int, scale: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        var hash = abs(seed.hashValue)
        for _ in 0..<count {
            hash = hash &* 1664525 &+ 1013904223
            let normalized = CGFloat(hash % 1000) / 1000.0
            result.append((normalized - 0.5) * scale)
        }
        return result
    }

    func path(in rect: CGRect) -> Path {
        let topOffsets    = offsets(count: steps, scale: raggedAmount)
        let bottomOffsets = offsets(count: steps, scale: raggedAmount)
        let leftOffsets   = offsets(count: steps, scale: raggedAmount)
        let rightOffsets  = offsets(count: steps, scale: raggedAmount)

        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + topOffsets[0]))

        for i in 1..<steps {
            let x = rect.minX + (rect.width / CGFloat(steps - 1)) * CGFloat(i)
            let y = rect.minY + topOffsets[i]
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.maxX + rightOffsets[0], y: rect.minY))
        for i in 1..<steps {
            let x = rect.maxX + rightOffsets[i]
            let y = rect.minY + (rect.height / CGFloat(steps - 1)) * CGFloat(i)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY + bottomOffsets[0]))
        for i in 1..<steps {
            let x = rect.maxX - (rect.width / CGFloat(steps - 1)) * CGFloat(i)
            let y = rect.maxY + bottomOffsets[i]
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.minX + leftOffsets[0], y: rect.maxY))
        for i in 1..<steps {
            let x = rect.minX + leftOffsets[i]
            let y = rect.maxY - (rect.height / CGFloat(steps - 1)) * CGFloat(i)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }
}
