// MapSnapshotView.swift
// Commonplace
//
// Async map snapshot component — replaces live Map views in feed cards.
// Generates a static MKMapSnapshotter image for a coordinate and caches it
// in memory. Much cheaper than a live Map view, visually identical for
// static thumbnails.
//
// Usage:
//   MapSnapshotView(latitude: lat, longitude: lon, size: CGSize(width: 48, height: 48))
//       .clipShape(RoundedRectangle(cornerRadius: 8))
//
// Cache is keyed by "lat,lon,widthxheight" — separate cache entries per size.
// Cache is in-memory only — cleared on app relaunch. Acceptable tradeoff
// since snapshots generate quickly and disk caching adds complexity.

import SwiftUI
import MapKit

// MARK: - MapSnapshotCache

final class MapSnapshotCache {
    static let shared = MapSnapshotCache()
    private init() {}
    private var cache: [String: UIImage] = [:]
    private let lock = NSLock()

    func get(key: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func set(key: String, image: UIImage) {
        lock.lock()
        defer { lock.unlock() }
        cache[key] = image
    }

    static func key(latitude: Double, longitude: Double, size: CGSize) -> String {
        "\(latitude),\(longitude),\(Int(size.width))x\(Int(size.height))"
    }
}

// MARK: - MapSnapshotView

struct MapSnapshotView: View {
    let latitude: Double
    let longitude: Double
    let size: CGSize

    @State private var snapshot: UIImage? = nil
    @State private var isLoaded = false

    var cacheKey: String {
        MapSnapshotCache.key(latitude: latitude, longitude: longitude, size: size)
    }

    var body: some View {
        Group {
            if let snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFill()
                    .opacity(isLoaded ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isLoaded = true
                        }
                    }
            } else {
                // Placeholder while generating
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay(
                        Image(systemName: "map")
                            .font(.system(size: size.width * 0.25))
                            .foregroundStyle(Color.gray.opacity(0.4))
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .task {
            guard snapshot == nil else { return }

            // Check cache first
            if let cached = MapSnapshotCache.shared.get(key: cacheKey) {
                snapshot = cached
                return
            }

            // Generate snapshot in background
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )

            let options = MKMapSnapshotter.Options()
            options.region = region
            options.size = size
            options.scale = await UIScreen.main.scale
            options.mapType = .standard
            options.showsBuildings = true

            let snapshotter = MKMapSnapshotter(options: options)

            guard let result = try? await snapshotter.start() else { return }

            // Draw a red pin marker on the snapshot
            let image = await MainActor.run {
                let renderer = UIGraphicsImageRenderer(size: size)
                return renderer.image { _ in
                    result.image.draw(at: .zero)
                    let point = result.point(for: coordinate)
                    let pinImage = UIImage(systemName: "mappin.circle.fill")?
                        .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
                    let pinSize = CGSize(width: 20, height: 20)
                    let pinRect = CGRect(
                        x: point.x - pinSize.width / 2,
                        y: point.y - pinSize.height,
                        width: pinSize.width,
                        height: pinSize.height
                    )
                    pinImage?.draw(in: pinRect)
                }
            }

            MapSnapshotCache.shared.set(key: cacheKey, image: image)
            await MainActor.run { snapshot = image }
        }
    }
}
