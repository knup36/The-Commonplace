// FolioHeaderCropView.swift
// Commonplace
//
// Crop UI presented after the user picks a header image for a Folio.
// Shows the image with drag and pinch gestures inside a fixed 16:9 frame.
// Confirm renders the visible region and returns cropped UIImage.
//
// Usage:
//   .sheet(item: $imageToCrop) { image in
//       FolioHeaderCropView(image: image) { cropped in
//           // save cropped image
//       }
//   }

import SwiftUI

struct FolioHeaderCropView: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    // Pan and pinch state
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    // Fixed crop frame aspect ratio — matches folio header height
    private let cropAspect: CGFloat = 16 / 7

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let cropWidth = geo.size.width
                let cropHeight = cropWidth / cropAspect

                VStack {
                    Spacer()

                    // Crop frame
                    ZStack {
                        Color.black

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cropWidth * scale, height: cropHeight * scale)
                            .offset(offset)
                            .clipped()

                        // Border overlay
                        Rectangle()
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                    }
                    .frame(width: cropWidth, height: cropHeight)
                    .clipped()
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                },
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                    )

                    Spacer()

                    Text("Pinch to zoom · Drag to reposition")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 24)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Adjust Header")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Use Photo") {
                        let cropped = cropImage()
                        onConfirm(cropped)
                    }
                    .bold()
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Crop

    func cropImage() -> UIImage {
        let cropAspectRatio = cropAspect
        let imageSize = image.size

        // Figure out how the image is scaled to fill the crop frame at current scale
        let imageAspect = imageSize.width / imageSize.height
        var drawWidth: CGFloat
        var drawHeight: CGFloat

        if imageAspect > cropAspectRatio {
            // Image is wider — constrained by height
            drawHeight = imageSize.height
            drawWidth = drawHeight * cropAspectRatio
        } else {
            // Image is taller — constrained by width
            drawWidth = imageSize.width
            drawHeight = drawWidth / cropAspectRatio
        }

        // Apply scale
        drawWidth /= scale
        drawHeight /= scale

        // Center crop adjusted by offset (convert screen offset to image coords)
        let scaleX = imageSize.width / (imageSize.width * scale / scale)
        let offsetX = -offset.width / scale * (imageSize.width / imageSize.width)
        let offsetY = -offset.height / scale * (imageSize.height / imageSize.height)

        let originX = (imageSize.width - drawWidth) / 2 + offsetX
        let originY = (imageSize.height - drawHeight) / 2 + offsetY

        let cropRect = CGRect(
            x: max(0, originX),
            y: max(0, originY),
            width: min(drawWidth, imageSize.width - max(0, originX)),
            height: min(drawHeight, imageSize.height - max(0, originY))
        )

        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
}
