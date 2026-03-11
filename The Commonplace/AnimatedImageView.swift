import SwiftUI
import SDWebImageSwiftUI

struct AnimatedImageView: View {
    let data: Data
    let isAnimated: Bool
    var crop: Bool = true
    
    static func isGIF(data: Data) -> Bool {
        guard data.count > 4 else { return false }
        return data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x38
    }
    
    var body: some View {
        if isAnimated {
            if crop {
                AnimatedImage(data: data)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
            } else {
                AnimatedImage(data: data)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }
        } else {
                    if let uiImage = AnimatedImageView.downsample(data: data, to: crop ? 400 : 800) {
                        if crop {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipped()
                        } else {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
    }
    static func downsample(data: Data, to maxDimension: CGFloat) -> UIImage? {
            let scale = UIScreen.main.scale
            let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else { return nil }
            let downsampleOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension * scale
            ] as CFDictionary
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
            return UIImage(cgImage: thumbnail)
        }
}
