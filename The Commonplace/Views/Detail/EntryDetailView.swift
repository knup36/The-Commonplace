import SwiftUI
import SwiftData
import MapKit

// MARK: - EntryDetailView
// Main detail view for all entry types.
// Acts as a container that delegates to type-specific section views.
// Handles text editing, toolbar, metadata footer, and search indexing on disappear.
// Screen: Entry Detail (tap any entry in the Feed, Collections, Tags, or Today tab)

struct EntryDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var textFieldFocused: Bool
    
    var style: any AppThemeStyle { themeManager.style }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhotoDetailSection(entry: entry, style: style, accentColor: entry.type.accentColor)
                AudioDetailSection(entry: entry, style: style, accentColor: entry.type.accentColor)
                LinkDetailSection(entry: entry, style: style, accentColor: entry.type.accentColor)
                MusicDetailSection(entry: entry, style: style, accentColor: entry.type.accentColor)
                JournalMetadataSection(entry: entry, style: style, accentColor: entry.type.accentColor)
                textContentSection
                TagInputView(tags: $entry.tagNames, accentColor: entry.type.accentColor, style: style)
                Divider()
                EntryMetadataFooter(entry: entry, style: style, accentColor: entry.type.accentColor)
            }
            .padding()
        }
        .background(entry.type.cardColor.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 100)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if isEditing {
                        Button("Done") {
                            entry.text = editText
                            isEditing = false
                            textFieldFocused = false
                        }
                        .bold()
                        .foregroundStyle(style.accent)
                    }
                    Button {
                        withAnimation { entry.isFavorited.toggle() }
                    } label: {
                        Image(systemName: entry.isFavorited ? "star.fill" : "star")
                            .foregroundStyle(style.accent)
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if entry.type == .text && entry.text.isEmpty {
                    editText = entry.text
                    isEditing = true
                    textFieldFocused = true
                }
            }
        }
        .onDisappear {
            SearchIndex.shared.index(entry: entry)
        }
    }
    
    // MARK: - Text Content Section
    
    @ViewBuilder
    var textContentSection: some View {
        if isEditing {
            AutoResizingTextEditor(text: $editText, minHeight: 32)
                .focused($textFieldFocused)
                .font(style.body)
                .foregroundStyle(style.primaryText)
                .onChange(of: editText) { _, newValue in entry.text = newValue }
        } else {
            Text(entry.text.isEmpty ? "Tap to add a note..." : entry.text)
                .font(style.body)
                .foregroundStyle(entry.text.isEmpty ? style.tertiaryText : style.primaryText)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    editText = entry.text
                    isEditing = true
                    textFieldFocused = true
                }
        }
    }
}
