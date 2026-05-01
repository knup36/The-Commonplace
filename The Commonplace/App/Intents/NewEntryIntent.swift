// NewEntryIntent.swift
// Commonplace
//
// App Intent that opens Commonplace directly to the new entry sheet.
// Appears in the Shortcuts app as "New Entry" and can be assigned
// to the iPhone Action Button via Settings → Action Button.
//
// When triggered, opens the app and fires a notification that FeedView
// listens for to present the add entry card automatically.
//
// No parameters required — intent opens the app and gets out of the way.

import AppIntents
import UIKit

struct NewEntryIntent: AppIntent {

    static var title: LocalizedStringResource = "New Entry"
    static var description = IntentDescription("Open Commonplace to capture a new entry.")

    // Opens the app rather than running in the background
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Small delay to let the app finish launching before firing
        try? await Task.sleep(nanoseconds: 400_000_000)
        NotificationCenter.default.post(name: .openNewEntrySheet, object: nil)
        return .result()
    }
}
