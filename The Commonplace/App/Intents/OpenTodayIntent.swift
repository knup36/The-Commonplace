// OpenTodayIntent.swift
// Commonplace
//
// App Intent that opens Commonplace directly to the Today tab.
// Useful for morning routines and Shortcuts automations.
//
// Appears in the Shortcuts app as "Open Today in Commonplace".
// Can be triggered via Siri: "Hey Siri, open Today in Commonplace."
//
// Posts a notification that the root tab view listens for
// to switch to the Today tab on launch.

import AppIntents
import Foundation

struct OpenTodayIntent: AppIntent {

    static var title: LocalizedStringResource = "Open Today in Commonplace"
    static var description = IntentDescription("Open Commonplace to the Today tab.")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        try? await Task.sleep(nanoseconds: 400_000_000)
        NotificationCenter.default.post(name: .navigateToToday, object: nil)
        return .result()
    }
}
