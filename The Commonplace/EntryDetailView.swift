import SwiftUI
import SwiftData
import MapKit
import PhotosUI
import LinkPresentation

struct EntryDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var entry: Entry
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isEditing = false
    @State private var editText = ""
    @State private var isAnalyzing = false
    @State private var showingExtractedText = false
    @State private var showingArticleReader = false
    @State private var isExtracting = false
    @State private var showingFullScreenImage = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingAudioRecorder = false
    @State private var linkURLText = ""
    @FocusState private var linkFieldFocused: Bool
    @FocusState private var textFieldFocused: Bool
    @Query var journalEntries: [JournalEntry]
    @Query(sort: \Habit.order) var habits: [Habit]

    var isInkwell: Bool { themeManager.current == .inkwell }

    var journalEntry: JournalEntry? {
        journalEntries.first { Calendar.current.isDate($0.date, inSameDayAs: entry.createdAt) }
    }

    var completedHabits: [Habit] {
        guard let je = journalEntry else { return [] }
        return habits.filter { je.completedHabits.contains($0.id.uuidString) }
    }

    var entryColor: Color {
        if isInkwell { return InkwellTheme.cardBackground(for: entry.type) }
        switch entry.type {
        case .text:     return Color(uiColor: .systemGray5)
        case .photo:    return Color.pink.opacity(0.15)
        case .audio:    return Color.orange.opacity(0.15)
        case .link:     return Color.blue.opacity(0.15)
        case .journal:  return Color(hex: "#BF5AF2").opacity(0.15)
        case .location: return Color.green.opacity(0.15)
        case .sticky:   return Color(hex: "#FFD60A").opacity(0.15)
        }
    }

    var entryAccentColor: Color {
        if isInkwell {
            switch entry.type {
            case .text:     return InkwellTheme.inkSecondary
            case .photo:    return InkwellTheme.collectionAccentColor(for: "#FF375F")
            case .audio:    return InkwellTheme.collectionAccentColor(for: "#FF9F0A")
            case .link:     return InkwellTheme.collectionAccentColor(for: "#0A84FF")
            case .journal:  return InkwellTheme.journalAccent
            case .location: return InkwellTheme.collectionAccentColor(for: "#30D158")
            case .sticky:   return InkwellTheme.amber
            }
        }
        switch entry.type {
        case .text:     return Color(uiColor: .systemGray)
        case .photo:    return Color.pink
        case .audio:    return Color.orange
        case .link:     return Color.blue
        case .journal:  return Color(hex: "#BF5AF2")
        case .location: return Color.green
        case .sticky:   return Color(hex: "#FFD60A")
        }
    }

    var iconForType: String {
        switch entry.type {
        case .text:     return "text.alignleft"
        case .photo:    return "photo"
        case .audio:    return "waveform"
        case .link:     return "link"
        case .journal:  return "bookmark.fill"
        case .location: return "mappin.circle.fill"
        case .sticky:   return "checklist"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                photoSection
                audioSection
                linkSection
                analyzingIndicator
                extractedTextSection
                journalMetadataSection
                textContentSection
                TagInputView(tags: $entry.tags, accentColor: entryAccentColor)
                journalPhotoSection
                Divider()
                metadataFooter
            }
            .padding()
        }
        .background(entryColor.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if isEditing {
                        Button("Done") {
                            entry.text = editText
                            isEditing = false
                            textFieldFocused = false
                        }
                        .bold()
                        .foregroundStyle(isInkwell ? InkwellTheme.amber : .accentColor)
                    }
                    Button {
                        withAnimation { entry.isFavorited.toggle() }
                    } label: {
                        Image(systemName: entry.isFavorited ? "star.fill" : "star")
                            .foregroundStyle(isInkwell ? InkwellTheme.amber : .yellow)
                    }
                }
            }
        }
        .sheet(isPresented: $showingArticleReader) {
            if let markdown = entry.markdownContent, markdown != "__failed__" {
                ArticleReaderView(markdown: markdown, title: entry.linkTitle)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            if let imageData = entry.imageData {
                FullScreenImageView(data: imageData)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if entry.type == .text && entry.text.isEmpty {
                    editText = entry.text
                    isEditing = true
                    textFieldFocused = true
                } else if entry.type == .link && (entry.url == nil || entry.url?.isEmpty == true) {
                    linkFieldFocused = true
                }
            }
            if entry.type == .photo && entry.extractedText == nil && entry.imageData != nil {
                isAnalyzing = true
                Task {
                    guard let imageData = entry.imageData else { isAnalyzing = false; return }
                    let result = await VisionService.analyze(imageData: imageData)
                    entry.extractedText = result.extractedText.isEmpty ? nil : result.extractedText
                    entry.visionTags = result.tags
                    isAnalyzing = false
                }
            }
            if entry.type == .link && entry.markdownContent == nil && entry.markdownContent != "__failed__" && entry.url != nil {
                isExtracting = true
                Task {
                    guard let urlString = entry.url else { isExtracting = false; return }
                    let result = await ArticleExtractor.extract(from: urlString)
                    if let markdown = result.markdown,
                       markdown.trimmingCharacters(in: .whitespacesAndNewlines).count > 200 {
                        entry.markdownContent = markdown
                        if entry.linkTitle == nil { entry.linkTitle = result.title }
                    } else {
                        entry.markdownContent = "__failed__"
                    }
                    isExtracting = false
                }
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    var photoSection: some View {
        if entry.type == .photo {
            if let imageData = entry.imageData {
                AnimatedImageView(data: imageData, isAnimated: AnimatedImageView.isGIF(data: imageData), crop: false)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { showingFullScreenImage = true }
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Change Photo", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(isInkwell ? entryAccentColor : .pink)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            entry.imageData = data
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
                        .background((isInkwell ? entryAccentColor : Color.pink).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(isInkwell ? entryAccentColor : .pink)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            entry.imageData = data
                            isAnalyzing = true
                            let result = await VisionService.analyze(imageData: data)
                            entry.extractedText = result.extractedText.isEmpty ? nil : result.extractedText
                            entry.visionTags = result.tags
                            isAnalyzing = false
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var audioSection: some View {
        if entry.type == .audio {
            if entry.audioData == nil {
                AudioEntryView(
                    audioData: Binding(get: { entry.audioData }, set: { entry.audioData = $0 }),
                    transcript: Binding(get: { entry.transcript ?? "" }, set: { entry.transcript = $0.isEmpty ? nil : $0 })
                )
            }
            if let audioData = entry.audioData {
                AudioPlayerView(audioData: audioData)
                if let transcript = entry.transcript, !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Transcript", systemImage: "text.bubble")
                            .font(.caption)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                        Text(transcript)
                            .font(isInkwell ? .system(.body, design: .serif) : .body)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background((isInkwell ? entryAccentColor : Color.orange).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Label("No transcript available", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background((isInkwell ? entryAccentColor : Color.orange).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    @ViewBuilder
    var linkSection: some View {
        if entry.type == .link {
            if entry.url == nil || entry.url?.isEmpty == true {
                TextField("https://", text: $linkURLText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($linkFieldFocused)
                    .padding(12)
                    .background((isInkwell ? entryAccentColor : Color.blue).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: linkURLText) { _, newValue in
                        if newValue.contains(".") && (newValue.hasPrefix("http") || newValue.hasPrefix("www")) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if linkURLText == newValue { saveURL() }
                            }
                        }
                    }
            } else {
                LinkPreviewView(entry: entry)
                if let urlString = entry.url, let url = URL(string: urlString) {
                    if isExtracting {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text("Saving article...")
                                .font(.caption)
                                .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                        }
                    } else if let mc = entry.markdownContent, mc != "__failed__" {
                        Label("Article Saved", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .green)
                    } else if entry.markdownContent == "__failed__" {
                        Label("Article unavailable", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                    }
                    HStack(spacing: 12) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isInkwell ? entryAccentColor : .blue)

                        if let mc = entry.markdownContent, mc != "__failed__" {
                            Button {
                                showingArticleReader = true
                            } label: {
                                Label("Read Article", systemImage: "doc.text")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(isInkwell ? InkwellTheme.inkSecondary : .indigo)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var analyzingIndicator: some View {
        if isAnalyzing {
            HStack(spacing: 8) {
                ProgressView()
                Text("Analyzing image...")
                    .font(.caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
            }
        }
    }

    @ViewBuilder
    var extractedTextSection: some View {
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
                            .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                            .rotationEffect(.degrees(showingExtractedText ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)
                if showingExtractedText {
                    Text(extractedText)
                        .font(.caption)
                        .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                        .padding(8)
                        .background(isInkwell ? InkwellTheme.surface : Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    var journalMetadataSection: some View {
        if entry.type == .journal {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(isInkwell ? .system(.title3, design: .serif) : .title3)
                    .fontWeight(.bold)
                    .foregroundStyle(entryAccentColor)
                if let je = journalEntry {
                    HStack(spacing: 16) {
                        if !je.weatherEmoji.isEmpty {
                            VStack(spacing: 2) {
                                Text(je.weatherEmoji).font(.largeTitle)
                                Text("Weather").font(.caption2)
                                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                            }
                        }
                        if !je.moodEmoji.isEmpty {
                            VStack(spacing: 2) {
                                Text(je.moodEmoji).font(.largeTitle)
                                Text("Mood").font(.caption2)
                                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                            }
                        }
                    }
                }
                if let je = journalEntry, !je.completedHabitSnapshots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Habits")
                            .font(.caption)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                        ForEach(je.completedHabitSnapshots, id: \.self) { habitName in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(entryAccentColor)
                                Text(habitName)
                                    .font(isInkwell ? .system(.subheadline, design: .serif) : .subheadline)
                                    .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                            }
                        }
                    }
                }
                Divider()
                Text("Note")
                    .font(.caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
            }
        }
    }

    @ViewBuilder
    var textContentSection: some View {
        if isEditing {
            AutoResizingTextEditor(text: $editText, minHeight: 32)
                .focused($textFieldFocused)
                .font(isInkwell ? .system(.body, design: .serif) : .body)
                .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                .onChange(of: editText) { _, newValue in entry.text = newValue }
        } else {
            Text(entry.text.isEmpty ? "" : entry.text)
                .font(isInkwell ? .system(.body, design: .serif) : .body)
                .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    editText = entry.text
                    isEditing = true
                    textFieldFocused = true
                }
        }
    }

    @ViewBuilder
    var journalPhotoSection: some View {
        if entry.type == .journal,
           let imageData = journalEntry?.journalImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    var metadataFooter: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.createdAt.formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                if let lat = entry.captureLatitude, let lon = entry.captureLongitude {
                    Button {
                        openInMaps(lat: lat, lon: lon, name: entry.captureLocationName)
                    } label: {
                        Label(entry.captureLocationName ?? "\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))", systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(entryAccentColor)
                            .frame(width: 20, height: 20)
                        Image(systemName: iconForType)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isInkwell ? InkwellTheme.background : .white)
                    }
                    Text(entry.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(entryAccentColor)
                }
                .padding(.leading, -5)
                .padding(.top, 3)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    func saveURL() {
        guard !linkURLText.isEmpty else { return }
        let urlString = linkURLText.hasPrefix("http") ? linkURLText : "https://\(linkURLText)"
        entry.url = urlString
        linkFieldFocused = false
        isExtracting = true
        Task {
            let fetcher = await LinkPreviewFetcher()
            await fetcher.fetch(urlString: urlString)
            if let metadata = await fetcher.metadata {
                entry.linkTitle = metadata.title
                if let imageProvider = metadata.imageProvider {
                    imageProvider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let uiImage = image as? UIImage {
                            DispatchQueue.main.async {
                                entry.previewImageData = uiImage.jpegData(compressionQuality: 0.7)
                            }
                        }
                    }
                }
            }
            let result = await ArticleExtractor.extract(from: urlString)
            if let markdown = result.markdown,
               markdown.trimmingCharacters(in: .whitespacesAndNewlines).count > 200 {
                entry.markdownContent = markdown
                if entry.linkTitle == nil { entry.linkTitle = result.title }
            } else {
                entry.markdownContent = "__failed__"
            }
            isExtracting = false
        }
    }

    func openInMaps(lat: Double, lon: Double, name: String?) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name ?? "Entry Location"
        mapItem.openInMaps()
    }
}
