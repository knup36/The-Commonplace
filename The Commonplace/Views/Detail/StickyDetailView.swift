// StickyDetailView.swift
// Commonplace
//
// Detail view for sticky/checklist entries.
//
// Architecture (v1.12.1 redesign):
//   - List is purely for display — no editors embedded in rows
//   - All text input happens via a safeAreaInset field at the bottom
//   - This field is always in the view hierarchy — tapping + or a row
//     simply focuses it, so keyboard and input appear simultaneously
//   - Unchecked items support long-press drag reorder via List .onMove
//   - Checked items are a separate non-draggable section below unchecked
//   - Swipe to delete on all items

import SwiftUI
import SwiftData

struct StickyDetailView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingDeleteConfirmation = false
    @State private var inputText: String = ""
    @State private var editingItemID: String? = nil  // nil = adding new
    @FocusState private var inputFocused: Bool
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { InkwellTheme.stickyAccent }
    var bgColor: Color { InkwellTheme.stickyCard }
    
    // MARK: - Item model
    
    struct StickyItem: Identifiable {
        let id: String
        let text: String
    }
    
    // MARK: - Computed items
    
    var uncheckedItems: [StickyItem] {
        entry.stickyItems.compactMap { raw in
            let parts = raw.components(separatedBy: "::")
            guard parts.count == 2 else { return nil }
            let id = parts[0]
            guard !entry.stickyChecked.contains(id) else { return nil }
            return StickyItem(id: id, text: parts[1])
        }
    }
    
    var checkedItems: [StickyItem] {
        entry.stickyItems.compactMap { raw in
            let parts = raw.components(separatedBy: "::")
            guard parts.count == 2 else { return nil }
            let id = parts[0]
            guard entry.stickyChecked.contains(id) else { return nil }
            return StickyItem(id: id, text: parts[1])
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Title
            Section {
                titleField
                    .listRowBackground(bgColor)
                    .listRowSeparator(.hidden)
            }
            
            // Progress
            if !uncheckedItems.isEmpty || !checkedItems.isEmpty {
                Section {
                    progressRow
                        .listRowBackground(bgColor)
                        .listRowSeparator(.hidden)
                }
            }
            
            // Unchecked items — draggable
            Section {
                ForEach(uncheckedItems) { item in
                    itemRow(item, checked: false)
                        .listRowBackground(bgColor)
                        .listRowSeparator(.hidden)
                }
                .onMove { from, to in
                    moveItems(from: from, to: to)
                }
                .onDelete { indexSet in
                    deleteUnchecked(at: indexSet)
                }
            }
            
            // Checked items — not draggable
            if !checkedItems.isEmpty {
                Section {
                    ForEach(checkedItems) { item in
                        itemRow(item, checked: true)
                            .listRowBackground(bgColor)
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        deleteChecked(at: indexSet)
                    }
                }
            }
            
            // Tags + footer
            Section {
                TagInputView(tags: $entry.tagNames, accentColor: accentColor, style: style)
                    .listRowBackground(bgColor)
                    .listRowSeparator(.hidden)
                EntryMetadataFooter(entry: entry, style: style, accentColor: accentColor)
                    .listRowBackground(bgColor)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(bgColor.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomInputBar
        }
        .onDisappear {
            SearchIndex.shared.index(entry: entry)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(accentColor)
                    }
                    Button {
                        withAnimation { entry.isPinned.toggle() }
                    } label: {
                        Image(systemName: entry.isPinned ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(accentColor)
                    }
                }
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Bottom input bar
    
    var bottomInputBar: some View {
        HStack(spacing: 12) {
            TextField(editingItemID == nil ? "New item..." : "Edit item...", text: $inputText)
                .font(.body)
                .foregroundStyle(style.primaryText)
                .focused($inputFocused)
                .onSubmit {
                    commitInput()
                }
            
            // + / confirm button
            Button {
                if inputFocused {
                    commitInput()
                    inputFocused = false
                } else {
                    startAdding()
                }
            } label: {
                Image(systemName: inputFocused ? "checkmark" : "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(accentColor)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(accentColor.opacity(0.15))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Title
    
    var titleField: some View {
        TextField("Title", text: Binding(
            get: { entry.stickyTitle ?? "" },
            set: { entry.stickyTitle = $0.isEmpty ? nil : $0 }
        ))
        .font(style.title)
        .fontWeight(.bold)
        .foregroundStyle(accentColor)
    }
    
    // MARK: - Progress
    
    var progressRow: some View {
        let total = uncheckedItems.count + checkedItems.count
        let done = checkedItems.count
        return HStack(spacing: 10) {
            ProgressView(value: Double(done), total: Double(total))
                .tint(accentColor)
            Text("\(done) of \(total) completed")
                .font(style.caption)
                .foregroundStyle(style.secondaryText)
        }
    }
    
    // MARK: - Item row
    
    func itemRow(_ item: StickyItem, checked: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleItem(item.id)
            } label: {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checked ? accentColor : style.tertiaryText)
            }
            .buttonStyle(.plain)
            
            Text(item.text)
                .font(style.body)
                .foregroundStyle(checked ? style.tertiaryText : style.primaryText)
                .strikethrough(checked, color: style.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    startEditing(item)
                }
        }
        .opacity(checked ? 0.5 : 1)
    }
    
    // MARK: - Input actions
    
    func startAdding() {
        editingItemID = nil
        inputText = ""
        inputFocused = true
    }
    
    func startEditing(_ item: StickyItem) {
        editingItemID = item.id
        inputText = item.text
        inputFocused = true
    }
    
    func commitInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        if let id = editingItemID {
            // Editing existing item
            if trimmed.isEmpty {
                entry.stickyItems.removeAll { $0.hasPrefix(id) }
                entry.stickyChecked.removeAll { $0 == id }
            } else {
                if let index = entry.stickyItems.firstIndex(where: { $0.hasPrefix(id) }) {
                    entry.stickyItems[index] = "\(id)::\(trimmed)"
                }
            }
            editingItemID = nil
            inputText = ""
            inputFocused = false
        } else {
            // Adding new item
            guard !trimmed.isEmpty else { return }
            let id = UUID().uuidString
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                entry.stickyItems.insert("\(id)::\(trimmed)", at: 0)
            }
            inputText = ""
            // Keep focused for rapid entry
            inputFocused = true
        }
    }
    
    // MARK: - List actions
    
    func toggleItem(_ id: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            if entry.stickyChecked.contains(id) {
                entry.stickyChecked.removeAll { $0 == id }
            } else {
                entry.stickyChecked.append(id)
            }
        }
    }
    
    func moveItems(from source: IndexSet, to destination: Int) {
        var unchecked = uncheckedItems
        unchecked.move(fromOffsets: source, toOffset: destination)
        let checkedRaw = entry.stickyItems.filter { raw in
            let id = raw.components(separatedBy: "::").first ?? ""
            return entry.stickyChecked.contains(id)
        }
        entry.stickyItems = unchecked.map { "\($0.id)::\($0.text)" } + checkedRaw
    }
    
    func deleteUnchecked(at offsets: IndexSet) {
        let toDelete = offsets.map { uncheckedItems[$0] }
        for item in toDelete {
            entry.stickyItems.removeAll { $0.hasPrefix(item.id) }
        }
    }
    
    func deleteChecked(at offsets: IndexSet) {
        let toDelete = offsets.map { checkedItems[$0] }
        for item in toDelete {
            entry.stickyItems.removeAll { $0.hasPrefix(item.id) }
            entry.stickyChecked.removeAll { $0 == item.id }
        }
    }
}
