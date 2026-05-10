// JournalPhotoDetailSection.swift
// Commonplace
//
// Displays and allows editing of the daily photo on a journal entry,
// when viewed from EntryDetailView (i.e. after the fact from the Feed).
//
// Mirrors the dailyPhotoBlock in JournalBlockView but adapted for
// the detail view context — uses PhotosPicker instead of ImagePicker,
// and respects EditModeManager for show/hide of editing controls.
//
// Uses entry.journalImagePath (not entry.imagePath) — same field
// as JournalBlockView so edits are reflected everywhere.
//
// Added: v2.4 — allows adding/changing/removing a journal photo
// after the day is over, from the Feed detail view.

import SwiftUI
import PhotosUI

struct JournalPhotoDetailSection: View {
    @Bindable var entry: Entry
    var style: any AppThemeStyle
    var accentColor: Color

    @EnvironmentObject var editMode: EditModeManager

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.journalImagePath != nil || editMode.isEditing {
                        Label("Daily Photo", systemImage: "camera.fill")
                            .font(style.typeBodySecondary)
                            .foregroundStyle(style.cardSecondaryText)
                    }

                    if let path = entry.journalImagePath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                // Photo exists — show it
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if editMode.isEditing {
                        Button {
                            removePhoto()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if editMode.isEditing {
                    changePhotoButton
                }

            } else if editMode.isEditing {
                // No photo yet, in edit mode — show add button
                addPhotoButton
            }

            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Saving photo...")
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardSecondaryText)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { await savePhoto(from: newItem) }
        }
    }

    // MARK: - Add Button

    var addPhotoButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Photo")
            }
            .font(.subheadline)
            .foregroundStyle(accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Change Button

    var changePhotoButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Label("Change Photo", systemImage: "photo")
                .font(style.typeCaption)
                .foregroundStyle(style.cardSecondaryText)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Remove Photo

    func removePhoto() {
        if let path = entry.journalImagePath {
            MediaFileManager.delete(path: path)
        }
        entry.journalImagePath = nil
        entry.touch()
    }

    // MARK: - Save Photo

    private func savePhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let rawData = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: rawData),
              let processedData = ImageProcessor.resizeAndCompress(image: uiImage)
        else { return }

        await MainActor.run { isProcessing = true }

        // Remove old photo from disk before replacing
        if let existingPath = entry.journalImagePath {
            MediaFileManager.delete(path: existingPath)
        }

        entry.journalImagePath = try? MediaFileManager.save(
            processedData,
            type: .journal,
            id: entry.id.uuidString
        )

        entry.touch()
        await MainActor.run { isProcessing = false }
    }
}
