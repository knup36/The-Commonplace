// PhotoDetailSection.swift
// Commonplace
//
// Displays the photo/video section within EntryDetailView.
// Shown when entry.type == .photo (Shot entries).
//
// Handles four states:
//   1. No media yet — shows picker for photo or video
//   2. Photo exists — shows image with option to change
//   3. Video exists — shows VideoPlayer with thumbnail
//   4. Analyzing — shows progress while Vision runs OCR on photos
//
// Updated v1.12 — extended to support video clips via videoPath.
// Video is compressed to 540p via VideoProcessor before saving.
// Thumbnail generated from first frame and saved separately.

import SwiftUI
import PhotosUI
import AVKit

struct PhotoDetailSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color
    
    @EnvironmentObject var editMode: EditModeManager

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isAnalyzing = false
    @State private var isProcessingVideo = false
    @State private var showingExtractedText = false
    @State private var showingFullScreenImage = false
    @State private var player: AVPlayer? = nil
    @State private var videoTempURL: URL? = nil
    @State private var videoSize: CGSize = CGSize(width: 9, height: 16)
    
    var isVideo: Bool { entry.videoPath != nil }
    
    var body: some View {
        if entry.type == .photo {
            VStack(alignment: .leading, spacing: 8) {
                if isVideo {
                    videoSection
                } else if entry.imagePath != nil {
                    photoSection
                } else {
                    emptyState
                }
                
                // Processing indicator
                if isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Analyzing image...")
                            .font(.caption)
                            .foregroundStyle(style.secondaryText)
                    }
                }
                
                if isProcessingVideo {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Processing video...")
                            .font(.caption)
                            .foregroundStyle(style.secondaryText)
                    }
                }
                
                // Extracted text — photos only
                if !isVideo, let extractedText = entry.extractedText, !extractedText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingExtractedText.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Label("Extracted Text", systemImage: "text.viewfinder")
                                    .font(.caption)
                                    .foregroundStyle(style.secondaryText)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(style.secondaryText)
                                    .rotationEffect(.degrees(showingExtractedText ? 180 : 0))
                            }
                        }
                        .buttonStyle(.plain)
                        if showingExtractedText {
                            Text(extractedText)
                                .font(.caption)
                                .foregroundStyle(style.secondaryText)
                                .padding(8)
                                .background(style.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
            .onAppear {
                setupVideoPlayer()
            }
            .onChange(of: entry.videoPath) { _, _ in
                player = nil
                setupVideoPlayer()
            }
            .onDisappear {
                player?.pause()
            }
        }
    }
    
    // MARK: - Photo Section
    
    var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let path = entry.imagePath,
               let imageData = MediaFileManager.load(path: path) {
                AnimatedImageView(
                    data: imageData,
                    isAnimated: AnimatedImageView.isGIF(data: imageData),
                    crop: false
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture { showingFullScreenImage = true }
                .fullScreenCover(isPresented: $showingFullScreenImage) {
                    if let path = entry.imagePath,
                       let imageData = MediaFileManager.load(path: path) {
                        FullScreenImageView(data: imageData)
                    }
                }
            }
            if editMode.isEditing {
                mediaPicker(label: "Change Shot", icon: "photo")
            }
        }
    }
    
    // MARK: - Video Section
    
    var videoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let player = player {
                VideoPlayerView(player: player)
                    .aspectRatio(videoSize.width / videoSize.height, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        if player.timeControlStatus == .playing {
                            player.pause()
                        } else {
                            player.play()
                        }
                    }
            } else {
                // Loading placeholder while player initialises
                ZStack {
                    if let thumbPath = entry.videoThumbnailPath,
                       let data = MediaFileManager.load(path: thumbPath),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                ZStack {
                                    Color.black.opacity(0.3)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    ProgressView()
                                        .tint(.white)
                                }
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accentColor.opacity(0.08))
                            .frame(height: 200)
                            .overlay(ProgressView().tint(accentColor))
                    }
                }
            }

            if let duration = entry.videoDuration {
                Label(formatDuration(duration), systemImage: "video.fill")
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
            }

            if editMode.isEditing {
                mediaPicker(label: "Change Video", icon: "video")
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    var emptyState: some View {
        if editMode.isEditing {
            VStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    Label("Choose Photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(style.cardDivider)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(style.cardPrimaryText)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task { await savePhoto(from: newItem) }
                }

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .videos
                ) {
                    Label("Choose Video", systemImage: "video")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(style.cardDivider)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(style.cardPrimaryText)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task { await saveVideo(from: newItem) }
                }
            }
        }
    }
    
    // MARK: - Media Picker
    
    func mediaPicker(label: String, icon: String) -> some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: icon == "video" ? .videos : .images
        ) {
            Label(label, systemImage: icon)
                .font(style.typeCaption)
                .foregroundStyle(style.cardSecondaryText)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if icon == "video" {
                    await saveVideo(from: newItem)
                } else {
                    await savePhoto(from: newItem)
                }
            }
        }
    }
    
    // MARK: - Save Photo
    
    private func savePhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let rawData = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: rawData),
              let processedData = ImageProcessor.resizeAndCompress(image: uiImage)
        else { return }
        
        // Clear video fields if switching from video to photo
        entry.videoPath = nil
        entry.videoDuration = nil
        entry.videoThumbnailPath = nil
        
        entry.imagePath = try? MediaFileManager.save(
            processedData,
            type: .image,
            id: entry.id.uuidString
        )
        
        // Screenshot detection — use raw data before compression for accurate EXIF reading
                entry.isScreenshot = ImageProcessor.isScreenshot(data: rawData)
                entry.isScreenshotDetected = true

                isAnalyzing = true
                let result = await VisionService.analyze(imageData: processedData)
                entry.extractedText = result.extractedText.isEmpty ? nil : result.extractedText
                entry.visionTags = result.tags
                isAnalyzing = false
                entry.touch()
            }
    
    // MARK: - Save Video
    
    private func saveVideo(from item: PhotosPickerItem?) async {
        guard let item else {
            print("saveVideo: no item")
            return
        }
        
        isProcessingVideo = true
        print("saveVideo: starting")
        
        // Load video data directly
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            print("saveVideo: failed to load data from picker item")
            isProcessingVideo = false
            return
        }
        print("saveVideo: got data, size \(data.count) bytes")
        
        // Write to temp file for processing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        do {
            try data.write(to: tempURL)
        } catch {
            print("saveVideo: failed to write temp file \(error)")
            isProcessingVideo = false
            try? FileManager.default.removeItem(at: tempURL)
            return
        }
        let url = tempURL
        print("saveVideo: wrote temp file to \(url)")
        
        // Generate thumbnail from first frame
        if let thumbnailData = VideoProcessor.thumbnail(url: url) {
            entry.videoThumbnailPath = try? MediaFileManager.save(
                thumbnailData,
                type: .thumbnail,
                id: "\(entry.id.uuidString)_thumb"
            )
            // Also set as imagePath so feed card can show thumbnail
            entry.imagePath = entry.videoThumbnailPath
        }
        
        // Compress video
        if let compressed = await VideoProcessor.compress(url: url) {
            entry.videoPath = try? MediaFileManager.save(
                compressed,
                type: .video,
                id: entry.id.uuidString
            )
        }
        
        // Get duration
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        entry.videoDuration = duration.map { CMTimeGetSeconds($0) }
        
        // Clear photo fields if switching from photo to video
                entry.extractedText = nil
                entry.visionTags = []
                
                entry.touch()
                isProcessingVideo = false
            }
    
    // MARK: - Helpers
    
    func setupVideoPlayer() {
        guard player == nil else { return }
        guard let path = entry.videoPath,
              let data = MediaFileManager.load(path: path) else { return }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(entry.id.uuidString)
            .appendingPathExtension("mp4")
        
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try data.write(to: url)
            } catch {
                print("VideoPlayer setup error writing file: \(error)")
                return
            }
        }
        
        videoTempURL = url
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
        }
        
        let asset = AVURLAsset(url: url)
        let avPlayer = AVPlayer(url: url)
        player = avPlayer
        
        // Read video dimensions
        Task {
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try? await track.load(.naturalSize)
                let transform = try? await track.load(.preferredTransform)
                if let size, let transform {
                    let transformed = size.applying(transform)
                    let width = abs(transformed.width)
                    let height = abs(transformed.height)
                    if width > 0 && height > 0 {
                        await MainActor.run {
                            videoSize = CGSize(width: width, height: height)
                        }
                    }
                }
            }
        }
    }
    
    func writeTempVideo(data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? data.write(to: url)
        return url
    }
    
    func formatDuration(_ duration: Double) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
