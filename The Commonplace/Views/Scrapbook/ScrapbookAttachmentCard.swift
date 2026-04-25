// ScrapbookAttachmentCard.swift
// Commonplace
//
// Scrapbook feed card for .attachment entries.
// Shows a paperclip at the top center, a 16:9 preview container
// (play icon for video, doc icon + text lines for PDF), filename,
// file size, note text, and tags below.
//
// Thumbnail and PDF first-page preview are placeholders for now —
// real previews can be generated at capture time in a future pass.

import SwiftUI

struct ScrapbookAttachmentCard: View {
    let entry: Entry

    private var inkColor: Color { ScrapbookTheme.inkPrimary }
    private var mutedColor: Color { ScrapbookTheme.inkSecondary }
    private var subtleColor: Color { ScrapbookTheme.inkDecorative }

    private var isPDF: Bool { entry.attachmentType == "pdf" }

    var body: some View {
        VStack(spacing: 0) {

            // Paperclip
            Image(systemName: "paperclip")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(mutedColor)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // 16:9 preview container
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(subtleColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(subtleColor.opacity(0.2), lineWidth: 0.5)
                    )

                if isPDF {
                    pdfPlaceholder
                } else {
                    videoPlaceholder
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .padding(.horizontal, 16)

            // Filename + file size
            VStack(spacing: 3) {
                if let filename = entry.attachmentFilename {
                    Text(filename)
                        .font(ScrapbookTheme.captionFont(size: 11))
                        .foregroundStyle(mutedColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let size = entry.attachmentFileSize {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                        .font(ScrapbookTheme.captionFont(size: 10))
                        .foregroundStyle(subtleColor)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 24)

            // Note text
            if !entry.text.isEmpty {
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
                .padding(.top, 12)

                Text(entry.text)
                    .font(ScrapbookTheme.bodyFont(size: 14))
                    .italic()
                    .foregroundStyle(mutedColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            // Tags
            let visibleTags = entry.tagNames.filter { !$0.hasPrefix("@") }
            if !visibleTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(visibleTags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(ScrapbookTheme.captionFont(size: 10))
                            .kerning(0.5)
                            .foregroundStyle(subtleColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .overlay(
                                Capsule().strokeBorder(subtleColor.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
                .padding(.top, 10)
            }

            // Date
            Text(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))
                .font(ScrapbookTheme.captionFont(size: 10))
                .kerning(1.2)
                .foregroundStyle(ScrapbookTheme.inkTertiary)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - PDF Placeholder

    private var pdfPlaceholder: some View {
        ZStack {
            VStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(subtleColor.opacity(0.25))
                        .frame(height: i == 0 ? 5 : 3)
                        .padding(.horizontal, CGFloat([8, 16, 12, 18, 14][i]))
                }
            }
            Image(systemName: "doc.fill")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(mutedColor.opacity(0.6))
        }
    }

    // MARK: - Video Placeholder

    private var videoPlaceholder: some View {
        Image(systemName: "play.circle")
            .font(.system(size: 32, weight: .light))
            .foregroundStyle(mutedColor.opacity(0.6))
    }
}
