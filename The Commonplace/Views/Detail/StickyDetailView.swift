import SwiftUI
import MapKit

// MARK: - StickyDetailView
// Detail view for sticky/checklist entries.
// Allows editing the title, adding/removing/checking items, and adding tags.
// Items animate to bottom when checked.
// Screen: Entry Detail (tap any sticky entry in the Feed or Collections tab)

struct StickyDetailView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var newItemText = ""
    @State private var isEditingTitle = false
    @State private var editTitle = ""
    @State private var editingItemID: String? = nil
    @State private var editingItemText: String = ""
    @State private var sortedChecked: Set<String> = []
    @State private var addItemEditorID = UUID()
    @FocusState private var newItemFocused: Bool
    @FocusState private var titleFocused: Bool
    @FocusState private var focusedItemID: String?
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { InkwellTheme.stickyAccent }
    var bgColor: Color { InkwellTheme.stickyCard }
    var isNewEntry: Bool { entry.stickyTitle == nil && entry.text.isEmpty }
    
    struct StickyItem: Identifiable {
        let id: String
        let text: String
    }
    
    var items: [StickyItem] {
        entry.stickyItems.compactMap { raw in
            let parts = raw.components(separatedBy: "::")
            guard parts.count == 2 else { return nil }
            return StickyItem(id: parts[0], text: parts[1])
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleSection
                progressSection
                Divider().overlay(style.surface)
                itemsList
                Divider().overlay(style.surface)
                TagInputView(tags: $entry.tagNames, accentColor: accentColor, style: style)
                Divider().overlay(style.surface)
                EntryMetadataFooter(entry: entry, style: style, accentColor: accentColor)
            }
            .padding()
        }
        .background(bgColor.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .keyboardAvoiding()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sortedChecked = Set(entry.stickyChecked)
            if isNewEntry {
                isEditingTitle = true
                editTitle = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { titleFocused = true }
            }
        }
        .onDisappear {
            SearchIndex.shared.index(entry: entry)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        withAnimation { entry.isPinned.toggle() }
                    } label: {
                        Image(systemName: entry.isPinned ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(accentColor)
                    }
                    if newItemFocused || isEditingTitle || focusedItemID != nil {
                        Button("Done") {
                            if isEditingTitle {
                                entry.stickyTitle = editTitle.isEmpty ? nil : editTitle
                                isEditingTitle = false
                            }
                            if newItemFocused {
                                addItem()
                            }
                            if focusedItemID != nil {
                                saveEditingItem()
                                focusedItemID = nil
                            }
                            newItemFocused = false
                        }
                        .bold()
                        .foregroundStyle(style.accent)
                    }
                }
            }
        }
    }
    
    // MARK: - Sub-views
    
    var titleSection: some View {
        Group {
            if isEditingTitle {
                TextField("Title", text: $editTitle)
                    .font(style.title)
                    .fontWeight(.bold)
                    .foregroundStyle(accentColor)
                    .focused($titleFocused)
                    .onSubmit {
                        entry.stickyTitle = editTitle.isEmpty ? nil : editTitle
                        isEditingTitle = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            newItemFocused = true
                        }
                    }
            } else {
                Text(entry.stickyTitle ?? "Untitled Sticky")
                    .font(style.title)
                    .fontWeight(.bold)
                    .foregroundStyle(accentColor)
                    .onTapGesture {
                        editTitle = entry.stickyTitle ?? ""
                        isEditingTitle = true
                        titleFocused = true
                    }
            }
        }
    }
    
    @ViewBuilder
    var progressSection: some View {
        if !items.isEmpty {
            HStack(spacing: 8) {
                ProgressView(value: Double(entry.stickyChecked.count), total: Double(items.count))
                    .tint(accentColor)
                Text("\(entry.stickyChecked.count) of \(items.count) completed")
                    .font(style.caption)
                    .foregroundStyle(style.secondaryText)
            }
        }
    }
    
    var itemsList: some View {
        VStack(spacing: 0) {
            addItemRow
            Divider().overlay(style.surface)
            ForEach(items.sorted { !sortedChecked.contains($0.id) && sortedChecked.contains($1.id) }) { item in
                stickyItemRow(item)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                Divider().overlay(style.surface)
            }
        }
    }
    
    func stickyItemRow(_ item: StickyItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                toggleItem(item.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        sortedChecked = Set(entry.stickyChecked)
                    }
                }
            } label: {
                Image(systemName: entry.stickyChecked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(entry.stickyChecked.contains(item.id)
                                     ? accentColor
                                     : style.tertiaryText)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            
            Text(item.text)
                .font(style.body)
                .foregroundStyle(entry.stickyChecked.contains(item.id)
                                 ? style.tertiaryText
                                 : style.primaryText)
                .strikethrough(entry.stickyChecked.contains(item.id), color: style.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(focusedItemID == item.id ? 0 : 1)
                .overlay(alignment: .topLeading) {
                    CommonplaceTextEditor(
                        text: focusedItemID == item.id ? $editingItemText : .constant(item.text),
                        placeholder: "",
                        usesSerifFont: style.usesSerifFonts,
                        minHeight: 28,
                        onSubmit: { saveEditingItem() }
                    )
                    .focused($focusedItemID, equals: item.id)
                    .opacity(focusedItemID == item.id ? 1 : 0)
                    .allowsHitTesting(focusedItemID == item.id)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    saveEditingItem()
                    editingItemText = item.text
                    editingItemID = item.id
                    focusedItemID = item.id
                }
            
            Button { entry.deleteStickyItem(item.id) } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(style.tertiaryText)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.vertical, 10)
    }
    
    var addItemRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(accentColor.opacity(0.6))
            CommonplaceTextEditor(
                text: $newItemText,
                placeholder: "Add item...",
                usesSerifFont: style.usesSerifFonts,
                minHeight: 28,
                onSubmit: addItem
            )
            .focused($newItemFocused)
            .id(addItemEditorID)
            if !newItemText.isEmpty {
                Button { addItem() } label: {
                    Image(systemName: "return").foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Helpers
    
    func toggleItem(_ id: String) {
        if entry.stickyChecked.contains(id) {
            entry.stickyChecked.removeAll { $0 == id }
        } else {
            entry.stickyChecked.append(id)
        }
    }
    
    func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let id = UUID().uuidString
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            entry.stickyItems.insert("\(id)::\(trimmed)", at: 0)
        }
        newItemText = ""
        addItemEditorID = UUID()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            newItemFocused = true
        }
    }
    
    func saveEditingItem() {
        guard let id = editingItemID else { return }
        let trimmed = editingItemText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            entry.deleteStickyItem(id)
        } else {
            if let index = entry.stickyItems.firstIndex(where: { $0.hasPrefix(id) }) {
                entry.stickyItems[index] = "\(id)::\(trimmed)"
            }
        }
        editingItemID = nil
        editingItemText = ""
    }
}
