import SwiftUI
import LinkPresentation

// MARK: - LinkDetailSection
// Displays the link section within EntryDetailView.
// Shown when entry.type == .link.
// Handles two states:
//   1. No URL yet — shows a text field to paste/type a URL
//   2. URL exists — shows LinkPreviewView, article save status, and action buttons
// Auto-saves URL when a valid address is detected while typing
// Screen: Entry Detail (tap any link entry in the Feed or Collections tab)

struct LinkDetailSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color
    
    @State private var linkURLText = ""
    @State private var isExtracting = false
    @State private var showingArticleReader = false
    @FocusState private var linkFieldFocused: Bool
    
    var body: some View {
        Group {
            if entry.type == .link {
                if entry.url == nil || entry.url?.isEmpty == true {
                    TextField("https://", text: $linkURLText)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($linkFieldFocused)
                        .padding(12)
                        .background(style.cardDivider)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onAppear {
                            linkFieldFocused = true
                            // Check clipboard for a URL
                            if let clip = UIPasteboard.general.string,
                               clip.hasPrefix("http") || clip.hasPrefix("www"),
                               linkURLText.isEmpty {
                                linkURLText = clip
                            }
                        }
                        .onChange(of: linkURLText) { _, newValue in
                            if newValue.contains(".") && (newValue.hasPrefix("http") || newValue.hasPrefix("www")) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    if linkURLText == newValue { saveURL() }
                                }
                            }
                        }
                } else {
                    // Content type selector
                    if entry.url != nil {
                        contentTypeSelector
                    }
                    
                    // Content based on type
                    if entry.linkContentType == "article",
                       let markdown = entry.markdownContent,
                       markdown != "__failed__" {
                        articlePreview(markdown: markdown)
                    } else {
                        LinkPreviewView(entry: entry)
                    }
                    
                    if let urlString = entry.url, let url = URL(string: urlString) {
                        HStack(spacing: 10) {
                            // Status label
                            if isExtracting {
                                HStack(spacing: 6) {
                                    ProgressView()
                                    Text("Saving...")
                                        .font(style.typeCaption)
                                        .foregroundStyle(style.secondaryText)
                                }
                            } else if let mc = entry.markdownContent, mc != "__failed__" {
                                Label("Article Saved", systemImage: "checkmark.circle.fill")
                                    .font(style.typeCaption)
                                    .foregroundStyle(style.secondaryText)
                            } else if entry.markdownContent == "__failed__" {
                                Label("Unavailable", systemImage: "exclamationmark.circle")
                                    .font(style.typeCaption)
                                    .foregroundStyle(style.tertiaryText)
                            }
                            
                            Spacer()
                            
                            // Action buttons
                            Button {
                                UIApplication.shared.open(url)
                            } label: {
                                Label("Safari", systemImage: "safari")
                                    .font(style.typeLabel)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accentColor)
                            
                            if let mc = entry.markdownContent, mc != "__failed__" {
                                Button {
                                    showingArticleReader = true
                                } label: {
                                    Label("Read", systemImage: "doc.text")
                                        .font(style.typeLabel)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(accentColor.opacity(0.5))
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingArticleReader) {
            if let markdown = entry.markdownContent, markdown != "__failed__" {
                ArticleReaderView(markdown: markdown, title: entry.linkTitle)
            }
        }
        .onAppear {
            if entry.type == .link && entry.markdownContent == nil && entry.url != nil {
                isExtracting = true
                Task {
                    guard let urlString = entry.url else { isExtracting = false; return }
                    let result = await ArticleExtractor.extract(from: urlString)
                    if let markdown = result.markdown,
                       markdown.trimmingCharacters(in: .whitespacesAndNewlines).count > 200 {
                        entry.markdownContent = markdown
                        if entry.linkTitle == nil { entry.linkTitle = result.title }
                        if entry.linkContentType == nil {
                            entry.linkContentType = "article"
                        }
                    } else {
                        entry.markdownContent = "__failed__"
                    }
                    isExtracting = false
                }
            }
        }
    }
    
    // MARK: - Content Type Selector
    
    var contentTypeSelector: some View {
        HStack(spacing: 0) {
            ForEach(["generic", "article", "video"], id: \.self) { type in
                let isSelected = (type == "generic" && entry.linkContentType == nil) ||
                entry.linkContentType == type
                Button {
                    entry.linkContentType = type == "generic" ? nil : type
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: iconFor(type))
                            .font(style.typeCaption)
                        Text(type.capitalized)
                            .font(style.typeLabel)
                    }
                    .foregroundStyle(isSelected ? accentColor : accentColor.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(isSelected ? accentColor.opacity(0.15) : Color.clear)
                }
                .buttonStyle(.plain)
                if type != "video" {
                    Divider()
                        .frame(height: 16)
                        .overlay(style.tertiaryText.opacity(0.3))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    func iconFor(_ type: String) -> String {
        switch type {
        case "article": return "doc.text"
        case "video":   return "play.circle"
        default:        return "link"
        }
    }
    
    // MARK: - Article Preview
    
    func articlePreview(markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = entry.linkTitle {
                Text(title)
                    .font(style.typeTitle3)
                    .foregroundStyle(style.cardPrimaryText)
                    .lineLimit(2)
            }
            if let urlString = entry.url {
                Text(urlString)
                    .font(style.typeCaption)
                    .foregroundStyle(style.cardMetadataText)
                    .lineLimit(1)
            }
            Divider()
                .overlay(style.cardDivider)
            Text(String(markdown.prefix(300)).trimmingCharacters(in: .whitespacesAndNewlines) + "...")
                .font(style.typeBodySecondary)
                .foregroundStyle(style.cardSecondaryText)
                .lineLimit(4)
                .lineSpacing(3)
        }
        .padding(12)
        .background(style.cardDivider)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style.cardBorder, lineWidth: 0.5)
        )
    }
    
    // MARK: - Helpers
    
    func saveURL() {
        guard !linkURLText.isEmpty else { return }
        let urlString = linkURLText.hasPrefix("http") ? linkURLText : "https://\(linkURLText)"
        entry.url = urlString
        entry.linkContentType = ShareExtensionIngestor.detectLinkContentType(urlString: urlString)
        entry.touch()
        linkFieldFocused = false
        isExtracting = true
        Task {
            let fetcher = await LinkPreviewFetcher()
            await fetcher.fetch(urlString: urlString)
            if let metadata = await fetcher.metadata {
                entry.linkTitle = metadata.title
                if let imageProvider = metadata.imageProvider {
                    imageProvider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let uiImage = image as? UIImage,
                           let data = uiImage.jpegData(compressionQuality: 0.7) {
                            DispatchQueue.main.async {
                                entry.previewImagePath = try? MediaFileManager.save(data, type: .preview, id: entry.id.uuidString)
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
                if entry.linkContentType == nil {
                    entry.linkContentType = "article"
                }
            } else {
                entry.markdownContent = "__failed__"
            }
            isExtracting = false
        }
    }
}
