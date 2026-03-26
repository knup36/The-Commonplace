// PersonInputView.swift
// Commonplace
//
// Dedicated input section for tagging people on entries.
// Appears below TagInputView on all entry detail views.
//
// People are stored in entry.tagNames with an "@" prefix (e.g. "@Sarah").
// The @ prefix is an internal namespace — users never see or type it.
// Person objects are auto-created when a new name is added.
//
// UI:
//   - Shows existing people on this entry as circular avatar chips
//   - Search field shows matching Person objects as suggestions
//   - "Create [name]" option appears when no match exists
//   - Tapping X on a chip removes the person from this entry
//
// Architecture:
//   - Reads/writes entry.tagNames directly (@ prefixed strings)
//   - Creates Person objects in SwiftData when new names are added
//   - Same pattern as TagInputView + Tag creation

import SwiftUI
import SwiftData

struct PersonInputView: View {
    @Binding var tags: [String]
    @Query(sort: \Person.name) var allPersons: [Person]
    var accentColor: Color = .accentColor
    var style: (any AppThemeStyle)?

    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    @Environment(\.modelContext) var modelContext

    /// People currently tagged on this entry (tag strings with @ prefix)
    var taggedPersonNames: [String] {
        tags.filter { $0.hasPrefix("@") }
            .map { String($0.dropFirst()) } // strip @ for display
    }

    /// Person suggestions based on input text, excluding already tagged ones
    var suggestions: [Person] {
        let tagged = Set(taggedPersonNames)
        if inputText.isEmpty {
            return allPersons.filter { !tagged.contains($0.name) }
        }
        return allPersons.filter {
            !tagged.contains($0.name) &&
            $0.name.localizedCaseInsensitiveContains(inputText)
        }
    }

    /// Whether to show a "Create [name]" option
    var showCreateOption: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let alreadyTagged = taggedPersonNames.contains { $0.lowercased() == trimmed.lowercased() }
        let alreadyExists = allPersons.contains { $0.name.lowercased() == trimmed.lowercased() }
        return !alreadyTagged && !alreadyExists
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Current people chips
            if !taggedPersonNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(taggedPersonNames, id: \.self) { name in
                            personChip(name: name)
                        }
                    }
                }
            }

            // Input field
            HStack(spacing: 6) {
                Image(systemName: "person")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Suggestions
            if isFocused && (!suggestions.isEmpty || showCreateOption) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // Existing person suggestions
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
                                .background(style?.surface ?? Color(uiColor: .systemGray5))
                                .foregroundStyle(style?.primaryText ?? .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        // Create new person option
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
                                .background(accentColor.opacity(0.15))
                                .foregroundStyle(accentColor)
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
        .animation(.easeInOut(duration: 0.15), value: suggestions.count)
    }

    // MARK: - Person Chip

    func personChip(name: String) -> some View {
        HStack(spacing: 5) {
            // Find person object for photo
            let person = allPersons.first { $0.name == name }
            personAvatar(name: name, photoPath: person?.profilePhotoPath, size: 18)
            Text(name)
                .font(.caption)
            Button {
                tags.removeAll { $0 == "@\(name)" }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(accentColor.opacity(0.15))
        .foregroundStyle(accentColor)
        .clipShape(Capsule())
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
                // Initial letter fallback
                Circle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.5, weight: .semibold))
                            .foregroundStyle(accentColor)
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
        
        // Add to entry's tagNames
        tags.append(tagString)
        inputText = ""
        
        // Create Person object if one doesn't exist
        let existingNames = allPersons.map { $0.name }
        if !existingNames.contains(where: { $0.lowercased() == cleaned.lowercased() }) {
            let person = Person(name: cleaned)
            modelContext.insert(person)
            try? modelContext.save()
            print("👤 Created Person: '\(person.name)'")
        }
    }
}
