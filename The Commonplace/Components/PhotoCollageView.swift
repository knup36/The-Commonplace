// PhotoCollageView.swift
// Commonplace
//
// Reusable collage layout for Shot entries with 1-4 images.
// Automatically detects image orientation and selects the best layout.
//
// Layout rules:
//   1 image  — full width, natural aspect ratio (unchanged from before)
//   2 images — both portrait: side by side
//              both landscape: stacked top/bottom
//              mixed: side by side
//   3 images — all portrait: tall hero left, two squares stacked right
//              all landscape: wide hero top, two squares side by side below
//              mixed: portrait hero left (or first if none), two squares right
//   4 images — always 2x2 grid
//
// All multi-image cells use square crop (scaledToFill) for clean uniform layout.
// Single image preserves natural aspect ratio.
// Gap between images: 2pt.
// Corner radius applied to outer collage only.
// onImageTap: optional callback with tapped image index — used by PhotoDetailSection
//             for per-image full screen presentation.
//
// Usage:
//   PhotoCollageView(paths: entry.allImagePaths, cornerRadius: 14)
//   PhotoCollageView(paths: entry.allImagePaths, cornerRadius: 14) { index in ... }

import SwiftUI

struct PhotoCollageView: View {
    let paths: [String]
    var cornerRadius: CGFloat = 14
    var onImageTap: ((Int) -> Void)? = nil
    
    private let gap: CGFloat = 2
    
    var images: [UIImage] {
        paths.compactMap { path in
            guard let data = MediaFileManager.load(path: path) else { return nil }
            return UIImage(data: data)
        }
    }
    
    var body: some View {
        switch images.count {
        case 0:
            EmptyView()
        case 1:
            singleImage(images[0])
        case 2:
            twoImageLayout
        case 3:
            threeImageLayout
        default:
            fourImageLayout
        }
    }
    
    // MARK: - Single Image
    
    func singleImage(_ image: UIImage) -> some View {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(Rectangle())
                .ifLet(onImageTap) { view, handler in
                    view.onTapGesture { handler(0) }
                }
        }
    
    // MARK: - Two Images
    
    var twoImageLayout: some View {
        let img0 = images[0]
        let img1 = images[1]
        let bothLandscape = isLandscape(img0) && isLandscape(img1)
        
        return Group {
            if bothLandscape {
                VStack(spacing: gap) {
                    squareCell(img0, index: 0)
                    squareCell(img1, index: 1)
                }
            } else {
                HStack(spacing: gap) {
                    squareCell(img0, index: 0)
                    squareCell(img1, index: 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    // MARK: - Three Images
    
    var threeImageLayout: some View {
        let img0 = images[0]
        let img1 = images[1]
        let img2 = images[2]
        let allLandscape = isLandscape(img0) && isLandscape(img1) && isLandscape(img2)
        let heroIndex = allLandscape ? 0 : (firstPortraitIndex() ?? 0)
        let otherIndices = (0..<3).filter { $0 != heroIndex }
        
        return Group {
            if allLandscape {
                VStack(spacing: gap) {
                    GeometryReader { geo in
                        Image(uiImage: img0)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.width * 0.5)
                            .clipped()
                    }
                    .aspectRatio(2, contentMode: .fit)
                                        .contentShape(Rectangle())
                                        .ifLet(onImageTap) { view, handler in
                                            view.onTapGesture { handler(0) }
                                        }
                    HStack(spacing: gap) {
                        squareCell(img1, index: 1)
                        squareCell(img2, index: 2)
                    }
                }
            } else {
                HStack(spacing: gap) {
                    GeometryReader { geo in
                        Image(uiImage: images[heroIndex])
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.width * 2 + gap)
                            .clipped()
                    }
                    .aspectRatio(0.5, contentMode: .fit)
                                        .contentShape(Rectangle())
                                        .ifLet(onImageTap) { view, handler in
                                            view.onTapGesture { handler(heroIndex) }
                                        }
                    VStack(spacing: gap) {
                        squareCell(images[otherIndices[0]], index: otherIndices[0])
                        squareCell(images[otherIndices[1]], index: otherIndices[1])
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    // MARK: - Four Images
    
    var fourImageLayout: some View {
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                squareCell(images[0], index: 0)
                squareCell(images[1], index: 1)
            }
            HStack(spacing: gap) {
                squareCell(images[2], index: 2)
                squareCell(images[3], index: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    // MARK: - Square Cell
    
    func squareCell(_ image: UIImage, index: Int) -> some View {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width)
                    .clipped()
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
            .ifLet(onImageTap) { view, handler in
                view.onTapGesture { handler(index) }
            }
        }
    
    // MARK: - Orientation Helpers
    
    func isPortrait(_ image: UIImage) -> Bool {
        image.size.height > image.size.width
    }
    
    func isLandscape(_ image: UIImage) -> Bool {
        image.size.width > image.size.height
    }
    
    func firstPortraitIndex() -> Int? {
        images.indices.first { isPortrait(images[$0]) }
    }
    
}
// MARK: - View Extension

extension View {
    @ViewBuilder
    func ifLet<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
