// OpenHomeIntent.swift
// Commonplace
//
// App Intent that opens Commonplace to the Home dashboard tab.
// Useful for quickly jumping into the app from Shortcuts or Siri.
//
// Appears in the Shortcuts app as "Open Home in Commonplace".
// Can be triggered via Siri: "Hey Siri, open Commonplace."
//
// Posts a notification that ContentView listens for
// to switch to the Home tab (tag 0) on launch.

import AppIntents
import Foundation

struct OpenHomeIntent: AppIntent {

    static var title: LocalizedStringResource = "Open Home in Commonplace"
    static var description = IntentDescription("Open Commonplace to the Home dashboard.")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        try? await Task.sleep(nanoseconds: 400_000_000)
        NotificationCenter.default.post(name: .navigateToHome, object: nil)
        return .result()
    }
}
