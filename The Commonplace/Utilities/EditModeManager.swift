// EditModeManager.swift
// Commonplace
//
// Environment object that carries edit/view mode state across detail views.
// Injected at the NavigationStack level so all child views can read and
// write edit state without prop drilling.
//
// Usage (reading):
//   @EnvironmentObject var editMode: EditModeManager
//   if editMode.isEditing { ... }
//
// Usage (writing):
//   editMode.enter()   // switch to edit mode
//   editMode.exit()    // switch to view mode
//   editMode.toggle()  // flip current state
//
// Convention:
//   - Detail views default to view mode (isEditing = false)
//   - New entries call enter() on appear so the keyboard is ready immediately
//   - Done button calls exit() and commits any pending changes
//   - Navigating back always commits — no discard mechanic

import SwiftUI
import Combine

final class EditModeManager: ObservableObject {
    @Published var isEditing: Bool = false

    func enter() {
        isEditing = true
    }

    func exit() {
        isEditing = false
    }

    func toggle() {
        isEditing.toggle()
    }
}
