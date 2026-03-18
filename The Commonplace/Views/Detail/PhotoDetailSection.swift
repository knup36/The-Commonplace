import SwiftUI
import PhotosUI

// MARK: - PhotoDetailSection
// Displays the photo section within EntryDetailView.
// Shown when entry.type == .photo.
// Handles three states:
//   1. No photo yet — shows PhotosPicker to choose one
//   2. Photo exists — shows the image with option to change it
//   3. Analyzing — shows progress indicator while Vision runs OCR
// Also includes extracted text section (collapsible OCR results)
// Screen: Entry Detail (tap any photo entry in the Feed or Collections tab)

struct PhotoDetailSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isAnalyzing = false
    @State private var showingExtractedText = false
    @State private var showingFullScreenImage = false
    
    var body: some View {
        if entry.type == .photo {
            if let path = entry.imagePath,
               let imageData = MediaFileManager.load(path: path) {
                AnimatedImageView(data: imageData, isAnimated: AnimatedImageView.isGIF(data: imageData), crop: false)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { showingFullScreenImage = true }
                    .fullScreenCover(isPresented: $showingFullScreenImage) {
                        if let path = entry.imagePath,
                           let imageData = MediaFileManager.load(path: path) {
                            FullScreenImageView(data: imageData)
                        }
                    }
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Change Photo", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            entry.imagePath = try? MediaFileManager.save(data, type: .image, id: entry.id.uuidString)
                            entry.extractedText = nil
                            isAnalyzing = true
                            let result = await VisionService.analyze(imageData: data)
                            entry.extractedText = result.extractedText.isEmpty ? nil : result.extractedText
                            entry.visionTags = result.tags
                            isAnalyzing = false
                        }
                    }
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(accentColor)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            entry.imagePath = try? MediaFileManager.save(data, type: .image, id: entry.id.uuidString)
                            isAnalyzing = true
                            let result = await VisionService.analyze(imageData: data)
                            entry.extractedText = result.extractedText.isEmpty ? nil : result.extractedText
                            entry.visionTags = result.tags
                            isAnalyzing = false
                        }
                    }
                }
            }
            
            // Analyzing indicator
            if isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Analyzing image...")
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                }
            }
            
            // Extracted text section
            if let extractedText = entry.extractedText, !extractedText.isEmpty {
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
    }
}
