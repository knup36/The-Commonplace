// AddNoteIntent.swift
// Commonplace
//
// App Intent that captures a text note silently in the background
// without opening the app. Siri prompts for the note text, then
// writes a SharedEntry to the App Group container. The main app
// ingests it on next launch via ShareExtensionIngestor.
//
// Appears in the Shortcuts app as "Add Note to Commonplace".
// Can be triggered via Siri: "Hey Siri, add a note to Commonplace."
//
// Does NOT open the app — runs entirely in the background.
// Future: chain with OpenEntryIntent (v2.15) to deep link to the new entry.

import AppIntents
import Foundation

struct AddNoteIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Note to Commonplace"
    static var description = IntentDescription("Capture a text note in Commonplace without opening the app.")

    // Runs in the background — does not open the app
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Note", description: "The text of the note to capture.")
    var noteText: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
            let entry = SharedEntry(
                type: "text",
                text: noteText
            )
            try AppGroupContainer.save(entry)
            return .result(dialog: "Note saved to Commonplace.")
        }
}
