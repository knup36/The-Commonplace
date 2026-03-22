import SwiftUI
import SwiftData

struct TagInputView: View {
    @Binding var tags: [String]
    @Query var entries: [Entry]
    var accentColor: Color = .accentColor
    var style: (any AppThemeStyle)?
    
    @State private var inputText = ""
    @FocusState private var isFocused: Bool
    
    @Environment(\.modelContext) var modelContext
    
    var allExistingTags: [String] {
        Array(Set(entries.flatMap { $0.tagNames }))
            .sorted()
            .filter { !tags.contains($0) }
    }
    
    var suggestions: [String] {
        if inputText.isEmpty {
            return allExistingTags
        }
        return allExistingTags.filter {
            $0.localizedCaseInsensitiveContains(inputText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Current tags
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(accentColor.opacity(0.15))
                            .foregroundStyle(accentColor)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Input field
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Add a tag...", text: $inputText)
                    .font(.body)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        addTag(inputText)
                    }
                    .onChange(of: inputText) { _, newValue in
                        // Auto add tag if user types comma
                        if newValue.hasSuffix(",") {
                            let tag = String(newValue.dropLast())
                            addTag(tag)
                        }
                    }
                if !inputText.isEmpty {
                    Button {
                        addTag(inputText)
                    } label: {
                        Image(systemName: "return")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Suggestions chips
            if isFocused && !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions.prefix(10), id: \.self) { suggestion in
                            Button {
                                addTag(suggestion)
                                inputText = ""
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(style?.surface ?? Color(uiColor: .systemGray5))
                                    .foregroundStyle(style?.primaryText ?? .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: suggestions.count)
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
        
        // Create a Tag object if one doesn't already exist for this name
        let existingTags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        if !existingTags.contains(where: { $0.name == cleaned }) {
            let tag = Tag(name: cleaned)
            modelContext.insert(tag)
            print("🏷️ Created Tag object: '\(tag.name)' at \(tag.createdAt)")
        }
    }
}
