// JournalNoteBlock.swift
// Commonplace
//
// Isolated text editor subview for the daily journal note.
// Extracted from JournalBlockView so that keystroke-driven re-renders
// are scoped to this view only — the parent card (mood grid, habits,
// weather pickers) is completely unaffected by typing.
//
// Owns its own @State text and debounce task.
// Loads from todayEntry on appear; saves back via debounced write.

import SwiftUI

struct JournalNoteBlock: View {
    let todayEntry: Entry?
    let style: any AppThemeStyle
    let journalAccent: Color
    let onCreateEntry: () -> Entry

    @State private var text: String = ""
    @State private var saveDebounceTask: Task<Void, Never>? = nil
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Daily Note", systemImage: "pencil")
                .font(style.typeBodySecondary)
                .foregroundStyle(style.cardSecondaryText)
            CommonplaceTextEditor(
                text: $text,
                placeholder: "How was your day...",
                usesSerifFont: false,
                minHeight: 60
            )
            .foregroundStyle(style.cardPrimaryText)
            .focused($focused)
            .onChange(of: text) { _, newValue in
                saveDebounceTask?.cancel()
                saveDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { save(newValue) }
                }
            }
        }
        .onAppear {
            text = todayEntry?.text ?? ""
        }
        .onChange(of: todayEntry?.id) { _, _ in
            text = todayEntry?.text ?? ""
        }
    }

    private func save(_ newText: String) {
        if let existing = todayEntry {
            existing.text = newText
            existing.touch()
        } else if !newText.isEmpty {
            let entry = onCreateEntry()
            entry.text = newText
            entry.touch()
        }
    }
}
