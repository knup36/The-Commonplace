import SwiftUI
import UIKit

struct FullScreenImageView: View {
    let data: Data
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            if let uiImage = UIImage(data: data) {
                ZoomableImageView(image: uiImage)
                    .ignoresSafeArea()
            }
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(20)
            }
        }
        .statusBarHidden(true)
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.tag = 100
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        // Double tap to zoom
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Only layout once when bounds are first available
        DispatchQueue.main.async {
            context.coordinator.layoutImageIfNeeded()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableImageView
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var hasLaidOut = false

        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }

        func layoutImageIfNeeded() {
            guard !hasLaidOut,
                  let scrollView = scrollView,
                  let imageView = imageView,
                  scrollView.bounds.width > 0,
                  scrollView.bounds.height > 0 else { return }

            hasLaidOut = true

            let screenSize = scrollView.bounds.size
            let imageSize = parent.image.size
            let widthRatio = screenSize.width / imageSize.width
            let heightRatio = screenSize.height / imageSize.height
            let scale = min(widthRatio, heightRatio)

            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale

            imageView.frame = CGRect(
                x: (screenSize.width - scaledWidth) / 2,
                y: (screenSize.height - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )
            scrollView.contentSize = screenSize
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frame = imageView.frame

            frame.origin.x = frame.size.width < boundsSize.width
                ? (boundsSize.width - frame.size.width) / 2 : 0
            frame.origin.y = frame.size.height < boundsSize.height
                ? (boundsSize.height - frame.size.height) / 2 : 0

            imageView.frame = frame
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            if scrollView.zoomScale > 1.0 {
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                let location = gesture.location(in: scrollView)
                let zoomRect = CGRect(
                    x: location.x - 50,
                    y: location.y - 50,
                    width: 100,
                    height: 100
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}
