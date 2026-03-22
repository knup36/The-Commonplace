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
                    .background(accentColor.opacity(0.08))
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
                LinkPreviewView(entry: entry)
                if let urlString = entry.url, let url = URL(string: urlString) {
                    if isExtracting {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text("Saving article...")
                                .font(.caption)
                                .foregroundStyle(style.secondaryText)
                        }
                    } else if let mc = entry.markdownContent, mc != "__failed__" {
                        Label("Article Saved", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(style.secondaryText)
                    } else if entry.markdownContent == "__failed__" {
                        Label("Article unavailable", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(style.tertiaryText)
                    }
                    HStack(spacing: 12) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)

                        if let mc = entry.markdownContent, mc != "__failed__" {
                            Button {
                                showingArticleReader = true
                            } label: {
                                Label("Read Article", systemImage: "doc.text")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(style.secondaryText)
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
                    } else {
                        entry.markdownContent = "__failed__"
                    }
                    isExtracting = false
                }
            }
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
            } else {
                entry.markdownContent = "__failed__"
            }
            isExtracting = false
        }
    }
}
