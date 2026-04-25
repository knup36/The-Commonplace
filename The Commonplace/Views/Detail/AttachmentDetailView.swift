// AttachmentDetailView.swift
// Commonplace
//
// Detail view for .attachment entries (PDFs and videos).
// On first open (no file attached yet), shows a prominent file picker button.
// Once a file is attached, shows a preview appropriate to the subtype:
//   - PDF: inline PDFKit viewer
//   - Video: VideoPlayerView (reuses existing component)
// Notes field and tag row sit below the preview, matching other detail views.
//
// File picking uses UIDocumentPickerViewController via DocumentPicker helper.
// Accepted types: PDF, MP4, MOV, M4V, AVI.
// Files are copied into MediaFileManager's attachments directory on pick.

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers
import AVFoundation

struct AttachmentDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var entry: Entry
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject private var editMode = EditModeManager()
        @State private var showingFilePicker = false
    @State private var showingDeleteConfirmation = false
    @State private var editText = ""
    @State private var isEditingNotes = false
    @FocusState private var notesFocused: Bool

    var style: any AppThemeStyle { themeManager.style }
    var entryAccent: Color { entry.type.detailAccentColor(for: themeManager.current) }
    var cardColor: Color { entry.type.cardColor(for: themeManager.current) }

    var hasFile: Bool { entry.attachmentPath != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: - File preview or picker prompt
                if hasFile {
                    filePreview
                } else {
                    filePickerPrompt
                }

                // MARK: - Notes
                Divider().overlay(style.cardDivider)

                if isEditingNotes {
                    CommonplaceTextEditor(
                        text: $editText,
                        placeholder: "Add notes...",
                        usesSerifFont: false,
                        minHeight: 32
                    )
                    .focused($notesFocused)
                    .foregroundStyle(style.primaryText)
                    .onChange(of: editText) { _, newValue in
                        entry.text = newValue
                        entry.touch()
                    }
                } else {
                    if !entry.text.isEmpty {
                        Text(entry.text)
                            .font(style.typeBody)
                            .foregroundStyle(style.cardPrimaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Add notes...")
                            .font(style.typeBody)
                            .foregroundStyle(style.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture {
                                editText = entry.text
                                isEditingNotes = true
                                notesFocused = true
                            }
                    }
                }

                // MARK: - Tags + metadata
                EntryTagRow(
                    tagNames: $entry.tagNames,
                    isPinned: entry.isPinned,
                    accentColor: entryAccent,
                    style: style
                )
                Divider().overlay(style.cardDivider)
                EntryMetadataFooter(entry: entry, style: style, accentColor: entryAccent)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .environmentObject(editMode)
                .background(cardColor.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditingNotes {
                    Button("Done") {
                        notesFocused = false
                        isEditingNotes = false
                        entry.touch()
                    }
                    .bold()
                    .foregroundStyle(entryAccent)
                } else {
                    Menu {
                        if hasFile {
                            Button {
                                showingFilePicker = true
                            } label: {
                                Label("Replace File", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        Button {
                            editText = entry.text
                            isEditingNotes = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                notesFocused = true
                            }
                        } label: {
                            Label("Edit Notes", systemImage: "rectangle.and.pencil.and.ellipsis")
                        }
                        Divider()
                        Button {
                            entry.isPinned.toggle()
                        } label: {
                            Label(entry.isPinned ? "Remove Bookmark" : "Bookmark",
                                  systemImage: entry.isPinned ? "bookmark.fill" : "bookmark")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(entryAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker(
                allowedTypes: [.pdf, .mpeg4Movie, .movie, .video,
                               UTType(filenameExtension: "m4v") ?? .video,
                               UTType(filenameExtension: "avi") ?? .video]
            ) { url in
                importFile(from: url)
            }
        }
        .onDisappear {
            SearchIndex.shared.index(entry: entry)
        }
        .confirmationDialog("Delete this entry?",
                            isPresented: $showingDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let path = entry.attachmentPath {
                    MediaFileManager.delete(path: path)
                }
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - File Picker Prompt

    var filePickerPrompt: some View {
        Button {
            showingFilePicker = true
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "paperclip")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(entryAccent)
                Text("Choose a File")
                    .font(style.typeTitle3)
                    .fontWeight(.medium)
                    .foregroundStyle(entryAccent)
                Text("PDF, MP4, MOV, M4V, AVI")
                    .font(style.typeCaption)
                    .foregroundStyle(style.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .background(entryAccent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(entryAccent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - File Preview

    @ViewBuilder
    var filePreview: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Filename + size header
            HStack(spacing: 12) {
                Image(systemName: entry.attachmentType == "pdf" ? "doc.fill" : "video.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(entryAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.attachmentFilename ?? "Attachment")
                        .font(style.typeBodySecondary)
                        .fontWeight(.medium)
                        .foregroundStyle(style.primaryText)
                        .lineLimit(2)
                    if let size = entry.attachmentFileSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(style.typeCaption)
                            .foregroundStyle(style.tertiaryText)
                    }
                }
                Spacer()
            }

            // Preview
            if entry.attachmentType == "pdf" {
                PDFPreviewView(entry: entry)
                    .frame(height: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                            if let path = entry.attachmentPath {
                                let url = MediaFileManager.containerURL.appendingPathComponent(path)
                                VideoPlayerView(player: AVPlayer(url: url))
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
        }
    }

    // MARK: - Import File

    func importFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let attachmentType = ext == "pdf" ? "pdf" : "video"

        do {
            let data = try Data(contentsOf: url)
            let path = try MediaFileManager.save(
                data,
                type: .attachment(extension: ext),
                id: entry.id.uuidString
            )
            entry.attachmentPath = path
            entry.attachmentType = attachmentType
            entry.attachmentFilename = filename
            entry.attachmentFileSize = data.count
            entry.touch()
            try? modelContext.save()
        } catch {
            print("Attachment import failed: \(error)")
        }
    }
}

// MARK: - PDF Preview

struct PDFPreviewView: UIViewRepresentable {
    let entry: Entry

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard let path = entry.attachmentPath,
              let data = MediaFileManager.load(path: path),
              let document = PDFDocument(data: data) else { return }
        pdfView.document = document
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
