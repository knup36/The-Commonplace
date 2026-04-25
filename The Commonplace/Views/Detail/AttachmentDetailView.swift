// AttachmentDetailView.swift
// Commonplace
//
// Detail view for .attachment entries (PDFs and videos).
// Follows the same EditModeManager pattern as EntryDetailView.
//
// States:
//   - No file + editing: shows inline file picker button (matches PhotoDetailSection style)
//   - File exists: shows preview (PDF inline via PDFKit, video via VideoPlayerView)
//   - Editing: shows "Replace File" button below preview, notes field active
//
// File picking uses DocumentPicker (UIDocumentPickerViewController).
// Accepted types: PDF, MP4, MOV, M4V, AVI.
// Files are copied into MediaFileManager's attachments directory via copyFile().

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
    @FocusState private var notesFocused: Bool

    var style: any AppThemeStyle { themeManager.style }
    var entryAccent: Color { entry.type.detailAccentColor(for: themeManager.current) }
    var cardColor: Color { entry.type.cardColor(for: themeManager.current) }
    var hasFile: Bool { entry.attachmentPath != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: - File section
                fileSection

                // MARK: - Notes
                textContentSection

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
                if editMode.isEditing {
                    Button("Done") {
                        notesFocused = false
                        entry.touch()
                        editMode.exit()
                    }
                    .bold()
                    .foregroundStyle(entryAccent)
                } else {
                    Menu {
                        Button {
                            editMode.enter()
                        } label: {
                            Label("Edit", systemImage: "rectangle.and.pencil.and.ellipsis")
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
        .onAppear {
            editText = entry.text
            // Auto-enter edit mode for new entries
            if Date().timeIntervalSince(entry.createdAt) < 10 {
                editMode.enter()
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

    // MARK: - File Section

    @ViewBuilder
    var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasFile {
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
                } else if let path = entry.attachmentPath {
                    let url = MediaFileManager.containerURL.appendingPathComponent(path)
                    VideoPlayerView(player: AVPlayer(url: url))
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Replace button — only in edit mode
                if editMode.isEditing {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Replace File", systemImage: "arrow.triangle.2.circlepath")
                            .font(style.typeCaption)
                            .foregroundStyle(style.cardSecondaryText)
                    }
                    .buttonStyle(.plain)
                }

            } else {
                // No file yet — show picker button in edit mode style
                if editMode.isEditing {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Choose File", systemImage: "paperclip")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(style.cardDivider)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(style.cardPrimaryText)
                    }
                    .buttonStyle(.plain)

                    Text("PDF, MP4, MOV, M4V, AVI")
                        .font(style.typeCaption)
                        .foregroundStyle(style.tertiaryText)
                }
            }
        }
    }

    // MARK: - Text Content Section

    @ViewBuilder
    var textContentSection: some View {
        if editMode.isEditing {
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
            }
        } else if !entry.text.isEmpty {
            Text(entry.text)
                .font(style.typeBody)
                .foregroundStyle(style.cardPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0
            let path = try MediaFileManager.copyFile(
                from: url,
                type: .attachment(extension: ext),
                id: entry.id.uuidString
            )
            entry.attachmentPath = path
            entry.attachmentType = attachmentType
            entry.attachmentFilename = filename
            entry.attachmentFileSize = fileSize
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
