// ScrapbookShotCard.swift
// Commonplace
//
// Scrapbook feed card for .photo (Shot) entries.
// Single image: full-size Polaroid with tape strip and caption.
// Multiple images (2-4): fanned stack of smaller Polaroids, each with
// its own deterministic rotation, slightly offset so all are visible.
// Tapping navigates to the detail view.
//
// Rotation range: -5 to +5 degrees, deterministic per entry + index.
// No image = placeholder with camera icon.

import SwiftUI

struct ScrapbookShotCard: View {
    let entry: Entry
    
    private let polaroidWidth: CGFloat = 240
    private let smallPolaroidWidth: CGFloat = 170
    private let borderWidth: CGFloat = 12
    private let chinHeight: CGFloat = 56
    private let stackOffset: CGFloat = 145
    
    var allPaths: [String] { entry.allImagePaths }
    var isMulti: Bool { allPaths.count > 1 }
    
    var body: some View {
        if isMulti {
            multiPolaroidStack
        } else {
            singlePolaroid
        }
    }
    
    // MARK: - Single Polaroid
    
    var singlePolaroid: some View {
        let photoSize = polaroidWidth - (borderWidth * 2)
        let rotation = deterministicRotation(seed: entry.id.uuidString, index: 0)
        
        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                photoCell(path: allPaths.first, size: photoSize)
                chinView(size: photoSize)
            }
            .padding(borderWidth)
            .background(ScrapbookTheme.polaroidWhite)
            .clipShape(RoundedRectangle(cornerRadius: ScrapbookTheme.cardCornerRadius))
            .shadow(color: ScrapbookTheme.cardShadowColor, radius: ScrapbookTheme.cardShadowRadius, x: 0, y: ScrapbookTheme.cardShadowY)
            
            tapeStrip
        }
        .rotationEffect(.degrees(rotation))
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Multi Polaroid Stack

        var multiPolaroidStack: some View {
            let count = min(allPaths.count, 4)
            return Group {
                switch count {
                case 2: twoPolaroids
                case 3: threePolaroids
                default: fourPolaroids
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }

        // MARK: - Two Polaroids (side by side)

        var twoPolaroids: some View {
            HStack(alignment: .center, spacing: -12) {
                smallPolaroid(index: 0)
                smallPolaroid(index: 1)
            }
        }

        // MARK: - Three Polaroids (2 top, 1 bottom centered)

        var threePolaroids: some View {
            VStack(spacing: -12) {
                HStack(alignment: .center, spacing: -12) {
                    smallPolaroid(index: 0)
                    smallPolaroid(index: 1)
                }
                smallPolaroid(index: 2)
            }
        }

        // MARK: - Four Polaroids (2x2 grid)

        var fourPolaroids: some View {
            VStack(spacing: -12) {
                HStack(alignment: .center, spacing: -12) {
                    smallPolaroid(index: 0)
                    smallPolaroid(index: 1)
                }
                HStack(alignment: .center, spacing: -12) {
                    smallPolaroid(index: 2)
                    smallPolaroid(index: 3)
                }
            }
        }

        // MARK: - Small Polaroid

        func smallPolaroid(index: Int) -> some View {
            let photoSize = smallPolaroidWidth - (borderWidth * 2)
            let rotation = deterministicRotation(seed: entry.id.uuidString, index: index)

            return ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    photoCell(path: allPaths[index], size: photoSize)
                    miniChinView(size: photoSize)
                }
                .padding(borderWidth)
                .background(ScrapbookTheme.polaroidWhite)
                .clipShape(RoundedRectangle(cornerRadius: ScrapbookTheme.cardCornerRadius))
                .shadow(color: ScrapbookTheme.cardShadowColor, radius: ScrapbookTheme.cardShadowRadius, x: 0, y: ScrapbookTheme.cardShadowY)

                tapeStrip
            }
            .rotationEffect(.degrees(rotation))
            .zIndex(Double(index))
        }

        // MARK: - Mini Chin (date only for multi-image)

        func miniChinView(size: CGFloat) -> some View {
            Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(ScrapbookTheme.captionFont(size: 9))
                .kerning(0.8)
                .foregroundStyle(ScrapbookTheme.inkTertiary)
                .frame(width: size, height: 32)
        }
    
    // MARK: - Photo Cell
    
    @ViewBuilder
    func photoCell(path: String?, size: CGFloat) -> some View {
        if let path = path,
           let data = MediaFileManager.load(path: path),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
        } else {
            Rectangle()
                .fill(ScrapbookTheme.inkDecorative.opacity(0.15))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(ScrapbookTheme.inkTertiary)
                )
        }
    }
    
    // MARK: - Chin View
    
    func chinView(size: CGFloat) -> some View {
        VStack(spacing: 4) {
            if !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(entry.text)
                    .font(ScrapbookTheme.bodyFont(size: isMulti ? 11 : 13))
                    .italic()
                    .foregroundStyle(ScrapbookTheme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(ScrapbookTheme.captionFont(size: 9))
                .kerning(0.8)
                .foregroundStyle(ScrapbookTheme.inkTertiary)
        }
        .frame(width: size, height: chinHeight)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Tape Strip
    
    var tapeStrip: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(ScrapbookTheme.tapeColor)
            .frame(width: 52, height: 18)
            .offset(y: -9)
    }
    
    // MARK: - Helpers
    
    func deterministicRotation(seed: String, index: Int) -> Double {
            let hash = abs((seed + "\(index)").hashValue)
            let normalized = Double(hash % 600) / 100.0
            let base = normalized - 3.0
            return index % 2 == 0 ? base : -base
        }
}
