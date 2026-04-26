// PDFReaderView.swift
// Commonplace
//
// Full-screen PDF reader for .attachment entries.
// Presented as a fullScreenCover from AttachmentDetailView.
// Supports pinch-to-zoom, scroll, and all native PDFView gestures.
// Dismiss via the close button in the navigation bar.

import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let entry: Entry
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    var entryAccent: Color { entry.type.detailAccentColor(for: themeManager.current) }

    var body: some View {
        NavigationStack {
            PDFKitView(entry: entry)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(entry.attachmentFilename ?? "Document")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(entryAccent)
                                .font(.system(size: 22))
                        }
                        .buttonStyle(.plain)
                    }
                }
        }
    }
}

// MARK: - PDFKit View

struct PDFKitView: UIViewRepresentable {
    let entry: Entry

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard pdfView.document == nil,
              let path = entry.attachmentPath,
              let data = MediaFileManager.load(path: path),
              let document = PDFDocument(data: data) else { return }
        pdfView.document = document
    }
}
