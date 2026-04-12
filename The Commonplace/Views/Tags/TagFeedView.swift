import SwiftUI
import SwiftData

// MARK: - TagFeedView
// Shows all entries that have a specific tag applied.
// Supports search within the tagged entries.
// Screen: Tags tab → tap any tag

struct TagFeedView: View {
    let tag: String
    @Query var entries: [Entry]
    @Query var allTags: [Tag]
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) var modelContext
    @State private var searchText = ""
    @State private var showingEmojiPicker = false
    @State private var promotedFolio: Tag? = nil
    
    var tagObject: Tag? {
        allTags.first { $0.name == tag }
    }
    
    var isAlreadyFolio: Bool {
        tagObject?.isFolio == true
    }
    
    var style: any AppThemeStyle { themeManager.style }
    
    var filteredEntries: [Entry] {
        let tagged = entries
            .filter { $0.tagNames.contains(tag) }
            .sorted { $0.createdAt > $1.createdAt }
        if searchText.isEmpty { return tagged }
        return tagged.filter { entryMatchesSearch($0, searchText: searchText) }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredEntries) { entry in
                    NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                        EntryRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
        .background(style.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .font(.caption)
                        .foregroundStyle(style.accent)
                    Text(tag)
                        .font(style.typeTitle3)
                        .foregroundStyle(style.primaryText)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isAlreadyFolio {
                    Button {
                        showingEmojiPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack.badge.plus")
                                .font(.system(size: 14))
                            Text("Promote")
                                .font(style.typeCaption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(style.accent)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search entries...")
        .sheet(isPresented: $showingEmojiPicker) {
            FolioPromotionSheet(
                tagName: tag,
                onSelect: { emoji, colorHex in
                    promotedFolio = promoteToFolio(emoji: emoji, colorHex: colorHex)
                    showingEmojiPicker = false
                },
                onCancel: {
                    showingEmojiPicker = false
                }
            )
        }
        .navigationDestination(item: $promotedFolio) { folio in
            FolioDetailView(tag: folio)
                .environmentObject(EditModeManager())
        }
    }
    
    // MARK: - Promotion
    
    @discardableResult
    func promoteToFolio(emoji: String, colorHex: String = "#888780") -> Tag? {
        let tagObj: Tag
        if let existing = tagObject {
            tagObj = existing
        } else {
            tagObj = Tag(name: tag)
            modelContext.insert(tagObj)
        }
        tagObj.subjectType = "folioGeneric"
        tagObj.subjectEmoji = emoji
        tagObj.colorHex = colorHex
        try? modelContext.save()
        return tagObj
    }
}
// MARK: - Emoji Picker Sheet

struct FolioPromotionSheet: View {
    let tagName: String
    let onSelect: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var emoji: String = ""
    @State private var selectedColorHex: String = "#888780"
    @FocusState private var focused: Bool
    
    var displayName: String {
        tagName
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Preview pill
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text(emoji.isEmpty ? "◆" : emoji)
                            .font(.system(size: 20))
                        Text(displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: selectedColorHex).opacity(0.2))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [Color(white: 0.85), Color(white: 0.6), Color(white: 0.85), Color(white: 0.5), Color(white: 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    )
                }
                .padding(.top, 24)
                
                // Emoji picker
                VStack(spacing: 8) {
                    Text("Choose an emoji")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("", text: $emoji)
                        .focused($focused)
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                focused = true
                            }
                        }
                        .onChange(of: emoji) { _, newValue in
                            if newValue.count > 0 {
                                let single = String(newValue.prefix(2))
                                if single != emoji { emoji = String(newValue.prefix(1)) }
                            }
                        }
                    
                    Button {
                        focused = true
                    } label: {
                        Label("Pick Emoji", systemImage: "face.smiling")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)
                }
                
                // Color picker
                VStack(spacing: 8) {
                    Text("Choose a color")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 10) {
                        Circle()
                            .fill(Color(white: 0.6))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if selectedColorHex == "#888780" {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { selectedColorHex = "#888780" }
                        
                        ForEach(CuratedColors.all, id: \.hex) { color in
                            Circle()
                                .fill(Color(hex: color.hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if selectedColorHex == color.hex {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { selectedColorHex = color.hex }
                        }
                    }
                    .padding(.horizontal, 32)
                }
                
                Spacer()
            }
            .navigationTitle("New Folio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Promote") {
                        guard !emoji.isEmpty else { return }
                        onSelect(emoji, selectedColorHex)
                    }
                    .bold()
                    .disabled(emoji.isEmpty)
                }
            }
        }
    }
}

