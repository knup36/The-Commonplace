// TagInputView.swift
// Commonplace
//
// Reusable tag input section for all entry detail views.
// Collapses to a small + button once tags exist — expands on tap.
// Suggestions appear from existing tags across all entries.

import SwiftUI
import SwiftData

struct TagInputView: View {
    @Binding var tags: [String]
    @Query var entries: [Entry]
    @Query var allTagObjects: [Tag]
    var accentColor: Color = .accentColor
    var style: (any AppThemeStyle)?
    @EnvironmentObject var editMode: EditModeManager
    
    @State private var inputText = ""
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool
    
    @Environment(\.modelContext) var modelContext
    
    var visibleTags: [String] {
        tags.filter { !$0.hasPrefix("@") }
    }
    
    var allExistingTags: [String] {
            let allNames = entries.flatMap { $0.tagNames }.filter { !$0.hasPrefix("@") }
            let counts = Dictionary(allNames.map { ($0, 1) }, uniquingKeysWith: +)
            return counts
                .filter { !tags.contains($0.key) }
                .sorted { $0.value > $1.value }
                .map { $0.key }
        }
        
        var suggestions: [String] {
            if inputText.isEmpty { return allExistingTags }
            return allExistingTags.filter {
                $0.localizedCaseInsensitiveContains(inputText)
            }
        }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Pills row — always visible when tags exist
            if !visibleTags.isEmpty || isExpanded {
                HStack(spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(visibleTags, id: \.self) { tag in
                                tagPill(tag)
                            }
                            // + button — only in edit mode
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
            }
            
            // Input field — only in edit mode
            if editMode.isEditing && (visibleTags.isEmpty || isExpanded) {
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .font(.caption)
                        .foregroundStyle(style?.pillForeground ?? .secondary)
                    TextField("Add a tag...", text: $inputText)
                        .font(.body)
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            addTag(inputText)
                            if visibleTags.isEmpty {
                                isExpanded = false
                            }
                        }
                        .onChange(of: inputText) { _, newValue in
                            if newValue.hasSuffix(",") {
                                addTag(String(newValue.dropLast()))
                            }
                        }
                        .onChange(of: isFocused) { _, focused in
                            if !focused && !inputText.isEmpty {
                                addTag(inputText)
                            }
                            if !focused {
                                isExpanded = false
                            }
                        }
                    if !inputText.isEmpty {
                        Button { addTag(inputText) } label: {
                            Image(systemName: "return")
                                .font(.caption)
                                .foregroundStyle(style?.pillForeground ?? .secondary)
                        }
                    }
                }
            }
            
            // Suggestions
            if isFocused && !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions.prefix(10), id: \.self) { suggestion in
                            Button {
                                addTag(suggestion)
                                inputText = ""
                            } label: {
                                let folioTag = allTagObjects.first { $0.name == suggestion && $0.isFolio }
                                HStack(spacing: 4) {
                                    if let folio = folioTag, let emoji = folio.subjectEmoji {
                                        Text(emoji).font(.caption)
                                        Text(folio.folioDisplayName)
                                            .font(.caption)
                                            .foregroundStyle(style?.primaryText ?? .primary)
                                    } else {
                                        Text(suggestion).font(.caption)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(folioTag != nil ? Color(hex: folioTag?.colorHex ?? "#888780").opacity(0.2) : style?.pillBackground ?? Color(uiColor: .systemGray5))
                                .foregroundStyle(accentColor)
                                .clipShape(Capsule())
                                .overlay(
                                    folioTag != nil ?
                                    Capsule().strokeBorder(
                                        LinearGradient(
                                            colors: [Color(white: 0.85), Color(white: 0.6), Color(white: 0.85), Color(white: 0.5), Color(white: 0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    ) : nil
                                )
                            }
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
    
    func tagPill(_ tag: String) -> some View {
        let folioTag = allTagObjects.first { $0.name == tag && $0.isFolio }
        return HStack(spacing: 4) {
            if let folio = folioTag, let emoji = folio.subjectEmoji {
                Text(emoji)
                    .font(.caption)
                Text(folio.folioDisplayName)
                    .font(.caption)
                    .foregroundStyle(style?.primaryText ?? .primary)
            } else {
                Text(tag)
                    .font(.caption)
            }
            if editMode.isEditing {
                Button {
                    tags.removeAll { $0 == tag }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(folioTag != nil ? Color(hex: folioTag?.colorHex ?? "#888780").opacity(0.2) : accentColor.opacity(0.2))
        .foregroundStyle(accentColor)
        .clipShape(Capsule())
        .overlay(
            folioTag != nil ?
            Capsule().strokeBorder(
                LinearGradient(
                    colors: [Color(white: 0.85), Color(white: 0.6), Color(white: 0.85), Color(white: 0.5), Color(white: 0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            ) : nil
        )
    }
    
    func addTag(_ text: String) {
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        guard !cleaned.isEmpty && !tags.contains(cleaned) else {
            inputText = ""
            return
        }
        tags.append(cleaned)
        inputText = ""
        let existingTags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        if !existingTags.contains(where: { $0.name == cleaned }) {
            let tag = Tag(name: cleaned)
            modelContext.insert(tag)
        }
    }
}
