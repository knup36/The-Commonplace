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
    
    @StateObject private var editMode = EditModeManager()
    @State private var editText = ""
    @State private var noteTitle = ""
    @State private var noteBody = ""
    @State private var showingDeleteConfirmation = false
    @FocusState private var textFieldFocused: Bool
    @FocusState private var noteTitleFocused: Bool
    @FocusState private var noteBodyFocused: Bool
    
    // Split entry.text into title (first line) and body (rest)
    func loadNoteParts() {
        let parts = entry.text.components(separatedBy: "\n")
        noteTitle = parts.first ?? ""
        noteBody = parts.dropFirst().joined(separator: "\n")
    }
    
    // Rejoin title and body back into entry.text
    func saveNoteParts() {
        if noteBody.isEmpty {
            entry.text = noteTitle
        } else {
            entry.text = noteTitle + "\n" + noteBody
        }
        entry.touch()
    }
    
    var style: any AppThemeStyle { themeManager.style }
    var entryAccent: Color { entry.type.detailAccentColor(for: themeManager.current) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhotoDetailSection(entry: entry, style: style, accentColor: entryAccent)
                AudioDetailSection(entry: entry, style: style, accentColor: entryAccent)
                LinkDetailSection(entry: entry, style: style, accentColor: entryAccent)
                MusicDetailSection(entry: entry, style: style, accentColor: entryAccent)
                JournalMetadataSection(entry: entry, style: style, accentColor: entryAccent)
                textContentSection
                PersonInputView(tags: $entry.tagNames, accentColor: entryAccent, style: style)
                TagInputView(tags: $entry.tagNames, accentColor: entryAccent, style: style)
                Divider()
                    .overlay(style.cardDivider)
                EntryMetadataFooter(entry: entry, style: style, accentColor: entryAccent)
            }
            .padding()
        }
        .environmentObject(editMode)
        .background(entry.type.cardColor(for: themeManager.current).ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .keyboardAvoiding()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if editMode.isEditing {
                        Button("Done") {
                            noteTitleFocused = false
                            noteBodyFocused = false
                            textFieldFocused = false
                            entry.touch()
                            editMode.exit()
                        }
                        .bold()
                        .foregroundStyle(entryAccent)
                    } else {
                        Button {
                            editMode.enter()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if entry.type == .text {
                                    noteTitleFocused = true
                                } else {
                                    textFieldFocused = true
                                }
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(entryAccent)
                                .offset(y: -2)
                        }
                        Menu {
                            Button {
                                withAnimation { entry.isPinned.toggle() }
                            } label: {
                                Label(entry.isPinned ? "Remove Bookmark" : "Bookmark", systemImage: entry.isPinned ? "bookmark.fill" : "bookmark")
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
        }
        .onAppear {
            if entry.type == .text {
                loadNoteParts()
                if entry.text.isEmpty {
                    editMode.enter()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        noteTitleFocused = true
                    }
                }
            } else if entry.text.isEmpty {
                editMode.enter()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    textFieldFocused = true
                }
            }
        }
        .onDisappear {
            SearchIndex.shared.index(entry: entry)
        }
        .confirmationDialog("Delete this entry?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Text Content Section
    
    @ViewBuilder
    var textContentSection: some View {
        if entry.type == .text {
            noteContentSection
        } else {
            genericContentSection
        }
    }
    
    // MARK: - Note Content (title + body split)
    
    var noteContentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title field — 34pt NY Black
            CommonplaceTextEditor(
                text: $noteTitle,
                placeholder: "",
                usesSerifFont: true,
                fontSize: 34,
                fontWeight: .black,
                minHeight: 44,
                onSubmit: {
                    noteTitleFocused = false
                    noteBodyFocused = true
                }
            )
            .focused($noteTitleFocused)
            .foregroundStyle(style.primaryText)
            .onChange(of: noteTitle) { _, _ in saveNoteParts() }
            
            // Body field — 17pt SF Rounded
            CommonplaceTextEditor(
                text: $noteBody,
                placeholder: noteTitle.isEmpty ? "Start writing..." : "Continue writing...",
                usesSerifFont: false,
                minHeight: 32
            )
            .focused($noteBodyFocused)
            .foregroundStyle(style.primaryText)
            .onChange(of: noteBody) { _, _ in saveNoteParts() }
        }
    }
    
    // MARK: - Generic Content (all other entry types)
    
    @ViewBuilder
    var genericContentSection: some View {
        if editMode.isEditing {
            CommonplaceTextEditor(
                text: $editText,
                placeholder: "Start writing...",
                usesSerifFont: false,
                minHeight: 32
            )
            .focused($textFieldFocused)
            .foregroundStyle(style.primaryText)
            .onChange(of: editText) { _, newValue in entry.text = newValue }
        } else {
            Text(entry.text.isEmpty ? "Tap to add a note..." : entry.text)
                .font(style.typeBody)
                .foregroundStyle(entry.text.isEmpty ? style.cardMetadataText : style.cardPrimaryText)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    editText = entry.text
                    editMode.enter()
                    textFieldFocused = true
                }
        }
    }
}
