// PersonInputView.swift
// Commonplace
//
// Dedicated people tagging section for all entry detail views.
// Collapses to a small + button once people are tagged — expands on tap.
// People are stored in entry.tagNames with an "@" prefix (e.g. "@Sarah").
// The @ prefix is internal — users never see or type it.

import SwiftUI
import SwiftData

struct PersonInputView: View {
    @Binding var tags: [String]
    @Query(sort: \Tag.name) var allPersonTags: [Tag]

    var allPersons: [Tag] { allPersonTags.filter { $0.isPerson } }
    var accentColor: Color = .accentColor
    var style: (any AppThemeStyle)?

    @EnvironmentObject var editMode: EditModeManager

    @State private var inputText = ""
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    @Environment(\.modelContext) var modelContext

    var taggedPersonNames: [String] {
        tags.filter { $0.hasPrefix("@") }
            .map { String($0.dropFirst()) }
    }

    var suggestions: [Tag] {
        let tagged = Set(taggedPersonNames)
        if inputText.isEmpty {
            return allPersons.filter { !tagged.contains($0.name) }
        }
        return allPersons.filter {
            !tagged.contains($0.name) &&
            $0.name.localizedCaseInsensitiveContains(inputText)
        }
    }

    var showCreateOption: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let alreadyTagged = taggedPersonNames.contains { $0.lowercased() == trimmed.lowercased() }
        let alreadyExists = allPersons.contains { $0.name.lowercased() == trimmed.lowercased() }
        return !alreadyTagged && !alreadyExists
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Chips row — always visible when people are tagged
            if !taggedPersonNames.isEmpty || isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(taggedPersonNames, id: \.self) { name in
                            personChip(name: name)
                        }
                        // + button inline with chips — only in edit mode
                        if !isExpanded && editMode.isEditing {
                            Button {
                                isExpanded = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isFocused = true
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(accentColor.opacity(0.08))
                                    .foregroundStyle(accentColor.opacity(0.6))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Input field — only in edit mode, shown when empty or expanded
            if editMode.isEditing && (taggedPersonNames.isEmpty || isExpanded) {
                HStack(spacing: 6) {
                    Image(systemName: "person")
                        .font(.caption)
                        .foregroundStyle(style?.pillForeground ?? .secondary)
                    TextField("Tag a person...", text: $inputText)
                        .font(.body)
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .onSubmit {
                            if let first = suggestions.first {
                                addPerson(first.name)
                            } else if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                                addPerson(inputText.trimmingCharacters(in: .whitespaces))
                            }
                        }
                        .onChange(of: isFocused) { _, focused in
                            if !focused { isExpanded = false }
                        }
                    if !inputText.isEmpty {
                        Button {
                            if let first = suggestions.first {
                                addPerson(first.name)
                            } else {
                                addPerson(inputText.trimmingCharacters(in: .whitespaces))
                            }
                        } label: {
                            Image(systemName: "return")
                                .font(.caption)
                                .foregroundStyle(style?.pillForeground ?? .secondary)
                        }
                    }
                }
            }

            // Suggestions
            if isFocused && (!suggestions.isEmpty || showCreateOption) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions.prefix(8)) { person in
                            Button {
                                addPerson(person.name)
                                inputText = ""
                            } label: {
                                HStack(spacing: 4) {
                                    personAvatar(name: person.name, photoPath: person.profilePhotoPath, size: 18)
                                    Text(person.name)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(style?.pillBackground ?? Color(uiColor: .systemGray5))
                                .foregroundStyle(style?.pillForeground ?? .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        if showCreateOption {
                            Button {
                                addPerson(inputText.trimmingCharacters(in: .whitespaces))
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.caption)
                                    Text("Create \"\(inputText.trimmingCharacters(in: .whitespaces))\"")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(style?.pillBackground ?? accentColor.opacity(0.15))
                                .foregroundStyle(style?.pillForeground ?? accentColor)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
        .animation(.easeInOut(duration: 0.15), value: suggestions.count)
    }

    // MARK: - Person Chip

    func personChip(name: String) -> some View {
            let person = allPersons.first { $0.name == name }
            return ZStack {
                Circle()
                    .strokeBorder(SharedTheme.goldRingGradient, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                personAvatar(name: name, photoPath: person?.profilePhotoPath, size: 26)
            }
            .onLongPressGesture {
                if editMode.isEditing {
                    tags.removeAll { $0 == "@\(name)" }
                }
            }
        }

    // MARK: - Person Avatar

    func personAvatar(name: String, photoPath: String?, size: CGFloat) -> some View {
        Group {
            if let path = photoPath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(style?.personAvatarBackground ?? accentColor.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.5, weight: .semibold))
                            .foregroundStyle(style?.personAvatarForeground ?? accentColor)
                    )
            }
        }
    }

    // MARK: - Add Person

    func addPerson(_ name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return }
        let tagString = "@\(cleaned)"
        guard !tags.contains(tagString) else {
            inputText = ""
            return
        }
        tags.append(tagString)
        inputText = ""
        isExpanded = false
        let existingNames = allPersons.map { $0.name }
        if !existingNames.contains(where: { $0.lowercased() == cleaned.lowercased() }) {
            let tag = Tag(name: cleaned)
            tag.subjectType = "person"
            modelContext.insert(tag)
            try? modelContext.save()
        }
    }
}
