// ShareView.swift
// CommonplaceShareExtension
//
// SwiftUI mini capture UI presented by the share extension.
// Shows a bottom sheet style interface with:
//   - Content preview (URL, image thumbnail, or text preview)
//   - Optional note text field
//   - Tag input
//   - Save and Cancel buttons
//
// Designed to be lightweight and fast — no SwiftData, no heavy dependencies.
// Saves via AppGroupContainer which writes to the shared App Group container.

import SwiftUI

struct ShareView: View {
    let entryType: String
    let url: String?
    let imageData: Data?
    let initialText: String
    let onSave: (SharedEntry) -> Void
    let onCancel: () -> Void

    @State private var noteText: String = ""
    @State private var tagInput: String = ""
    @State private var tags: [String] = []
    @FocusState private var noteFocused: Bool

    var entryTypeDisplay: String {
        switch entryType {
        case "link":     return "Link"
        case "photo":    return "Photo"
        case "text":     return "Note"
        case "music":    return "Music"
        case "location": return "Place"
        default:         return "Note"
        }
    }

    var entryTypeIcon: String {
        switch entryType {
        case "link":     return "link"
        case "photo":    return "photo.fill"
        case "text":     return "text.alignleft"
        case "music":    return "music.note"
        case "location": return "mappin.circle.fill"
        default:         return "text.alignleft"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(uiColor: .systemGray4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: entryTypeIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Add to Commonplace")
                            .font(.headline)
                    }
                    Spacer()
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Content preview
                        contentPreview
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // Note field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                            TextField("Add a note...", text: $noteText, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal, 20)
                                .focused($noteFocused)
                        }

                        // Tags
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            // Existing tags
                            if !tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(tags, id: \.self) { tag in
                                            HStack(spacing: 4) {
                                                Text(tag)
                                                    .font(.caption)
                                                Button {
                                                    tags.removeAll { $0 == tag }
                                                } label: {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 9, weight: .bold))
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.accentColor.opacity(0.12))
                                            .foregroundStyle(Color.accentColor)
                                            .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            // Tag input
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Add a tag...", text: $tagInput)
                                    .font(.body)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .onSubmit { addTag() }
                                    .onChange(of: tagInput) { _, newValue in
                                        if newValue.hasSuffix(",") {
                                            tagInput = String(newValue.dropLast())
                                            addTag()
                                        }
                                    }
                            }
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 20)
                        }

                        // Save button
                        Button {
                            saveEntry()
                        } label: {
                            Text("Save to Commonplace")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -4)
        }
        .ignoresSafeArea()
        .onAppear {
            // Pre-fill note with initial text for text entries
            if entryType == "text" {
                noteText = initialText
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                noteFocused = true
            }
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    var contentPreview: some View {
        switch entryType {
        case "link", "music":
            if let url {
                HStack(spacing: 10) {
                    Image(systemName: entryType == "music" ? "music.note" : "link")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        case "photo":
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        case "location":
            if let url {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    func addTag() {
        let cleaned = tagInput
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        guard !cleaned.isEmpty && !tags.contains(cleaned) else {
            tagInput = ""
            return
        }
        tags.append(cleaned)
        tagInput = ""
    }

    func saveEntry() {
        // Add any pending tag input
        if !tagInput.isEmpty { addTag() }

        let entry = SharedEntry(
            type: entryType,
            text: noteText,
            url: url,
            imageData: imageData,
            tags: tags
        )
        onSave(entry)
    }
}
