// ScrapbookAttachmentCard.swift
// Commonplace
//
// Scrapbook feed card for .attachment entries.
//
// PDF entries render as a landscape manila folder card — warm kraft paper color,
// tab in the upper left labelled "PDF", filename on the folder body. Randomly
// rotated like Polaroid cards using a seeded angle derived from entry.id.
//
// Video entries render as a raw edge-to-edge thumbnail with:
//   - A paperclip SF Symbol overlaid at the top center
//   - Filename (no extension) overlaid top-left with a dark scrim for legibility
//   - File type badge (.mp4, .mov etc) overlaid bottom-left
//   - A subtle play chevron in the center
//
// Note text and tags render below both card types in the standard scrapbook style.

import SwiftUI

struct ScrapbookAttachmentCard: View {
    let entry: Entry
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    private var inkColor: Color { ScrapbookTheme.inkPrimary }
    private var mutedColor: Color { ScrapbookTheme.inkSecondary }
    private var subtleColor: Color { ScrapbookTheme.inkDecorative }
    
    private var isPDF: Bool { entry.attachmentType == "pdf" }
    
    // Deterministic rotation from entry id — same pattern as ScrapbookShotCard
    private var cardRotation: Double {
        let hash = abs(entry.id.hashValue)
        let index = hash % 11
        let angles = [-4.0, -3.0, -2.5, -1.5, -1.0, 0.5, 1.0, 1.5, 2.5, 3.0, 3.5]
        return angles[index]
    }
    
    // Filename without extension
    private var filenameWithoutExtension: String {
        guard let filename = entry.attachmentFilename else { return "" }
        return (filename as NSString).deletingPathExtension
    }
    
    // File type badge label e.g. ".mp4"
    private var fileTypeBadge: String {
        guard let filename = entry.attachmentFilename else { return "" }
        let ext = (filename as NSString).pathExtension.lowercased()
        return ext.isEmpty ? "" : ".\(ext)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isPDF {
                pdfFolderCard
            } else {
                videoThumbnailCard
            }
            
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
                .padding(.top, 16)
                
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
    
    // MARK: - PDF Manila Folder Card
    
    private var pdfFolderCard: some View {
        // Landscape folder — tab upper left, filename on body
        let folderColor = Color(red: 0.72, green: 0.60, blue: 0.42)
        let folderBody = Color(red: 0.80, green: 0.68, blue: 0.50)
        let tabColor = Color(red: 0.67, green: 0.55, blue: 0.38)
        let textColor = Color(red: 0.32, green: 0.20, blue: 0.08)
        
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Tab row — sits above the folder body
                HStack(spacing: 0) {
                    // Tab
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(tabColor)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(folderBody.opacity(0.6))
                            .padding(1)
                        Text("PDF")
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .kerning(1.5)
                            .foregroundStyle(textColor)
                    }
                    .frame(width: 58, height: 20)
                    
                    Spacer()
                }
                
                // Folder body
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(folderColor)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(folderBody)
                        .padding(1)
                    
                    // Filename
                    VStack(spacing: 4) {
                        if let filename = entry.attachmentFilename {
                            let name = (filename as NSString).deletingPathExtension
                            Text(name)
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundStyle(textColor)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 20)
                        }
                        if let size = entry.attachmentFileSize {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                .font(.system(size: 9, weight: .regular, design: .serif))
                                .foregroundStyle(textColor.opacity(0.55))
                        }
                    }
                }
                .frame(height: 130)
            }
        }
        .frame(maxWidth: isIPad ? 360 : .infinity)
                .rotationEffect(.degrees(cardRotation))
                .padding(.vertical, 8)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 1, y: 3)
    }
    
    // MARK: - Video Thumbnail Card
    
    private var videoThumbnailCard: some View {
        ZStack(alignment: .top) {
            // Thumbnail or dark placeholder
            ZStack {
                if let thumbnailPath = entry.attachmentThumbnailPath,
                   let uiImage = MediaFileManager.loadImage(path: thumbnailPath) {                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                } else {
                    // Fallback dark background when no thumbnail
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                }
                
                // Top scrim for filename legibility
                LinearGradient(
                    colors: [.black.opacity(0.65), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 70)
                .frame(maxWidth: .infinity, alignment: .top)
                
                // Bottom scrim for badge legibility
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                .frame(maxWidth: .infinity, alignment: .bottom)
                
                // Subtle play indicator
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
                
                // Filename top-left
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(filenameWithoutExtension)
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.leading, 10)
                            .padding(.top, 10)
                        Spacer()
                    }
                    Spacer()
                    // File type badge bottom-left
                    HStack {
                        if !fileTypeBadge.isEmpty {
                            Text(fileTypeBadge)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .padding(.leading, 10)
                                .padding(.bottom, 8)
                        }
                        Spacer()
                    }
                }
                .frame(height: 160)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Paperclip overlaid at top center, hanging above the card
            Image(systemName: "paperclip")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(mutedColor)
                .offset(y: -14)
        }
        .frame(maxWidth: isIPad ? 480 : .infinity)
                .rotationEffect(.degrees(cardRotation))
                .padding(.top, 16)
                .padding(.horizontal, 8)
                .shadow(color: .black.opacity(0.18), radius: 4, x: 1, y: 3)
    }
}
