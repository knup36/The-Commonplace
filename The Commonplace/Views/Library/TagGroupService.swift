// TagGroupService.swift
// Commonplace
//
// Manages tag group assignments for the Library Tags segment.
// Pure UI layer — no effect on tag matching, entry connections, or search.
//
// Storage: UserDefaults only. Two keys:
//   - "tagGroups": JSON-encoded [String: [String]] — groupName → [tagName]
//   - "tagGroupOrder": JSON-encoded [String] — ordered list of group names
//
// No SwiftData models or schema changes needed.

import Foundation
import Combine
import SwiftUI

final class TagGroupService: ObservableObject {

    static let shared = TagGroupService()

    private let groupsKey = "tagGroups"
    private let orderKey  = "tagGroupOrder"

    // MARK: - Published state

    @Published private(set) var groups: [String: [String]] = [:]
    @Published private(set) var groupOrder: [String] = []

    private init() {
        load()
    }

    // MARK: - Read

    /// Returns the group name for a given tag, or nil if ungrouped.
    func group(for tag: String) -> String? {
        groups.first(where: { $0.value.contains(tag) })?.key
    }

    /// Returns all tags assigned to a group, in their stored order.
    func tags(in group: String) -> [String] {
        groups[group] ?? []
    }

    // MARK: - Write

    /// Assigns a tag to a group. Removes it from any previous group first.
    func assign(tag: String, to groupName: String) {
        removeFromAllGroups(tag: tag)
        groups[groupName, default: []].append(tag)
        save()
    }

    /// Removes a tag from all groups (moves it to Ungrouped).
    func ungroup(tag: String) {
        removeFromAllGroups(tag: tag)
        save()
    }

    /// Creates a new empty group and appends it to the order.
    func createGroup(name: String) {
        guard !name.isEmpty, groups[name] == nil else { return }
        groups[name] = []
        groupOrder.append(name)
        save()
    }

    /// Renames a group, preserving its tags and position in order.
    func renameGroup(from oldName: String, to newName: String) {
        guard !newName.isEmpty, groups[oldName] != nil, groups[newName] == nil else { return }
        let tags = groups.removeValue(forKey: oldName) ?? []
        groups[newName] = tags
        if let index = groupOrder.firstIndex(of: oldName) {
            groupOrder[index] = newName
        }
        save()
    }

    /// Deletes a group. Tags that were in it become ungrouped.
    func deleteGroup(name: String) {
        groups.removeValue(forKey: name)
        groupOrder.removeAll { $0 == name }
        save()
    }

    /// Reorders groups by moving offsets — used by List .onMove on group headers.
    func moveGroups(from source: IndexSet, to destination: Int) {
        groupOrder.move(fromOffsets: source, toOffset: destination)
        save()
    }

    /// Reorders tags within a group.
    func moveTags(in groupName: String, from source: IndexSet, to destination: Int) {
        groups[groupName]?.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Private

    private func removeFromAllGroups(tag: String) {
        for key in groups.keys {
            groups[key]?.removeAll { $0 == tag }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsKey)
        }
        if let data = try? JSONEncoder().encode(groupOrder) {
            UserDefaults.standard.set(data, forKey: orderKey)
        }
        objectWillChange.send()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: groupsKey),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            groups = decoded
        }
        if let data = UserDefaults.standard.data(forKey: orderKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            groupOrder = decoded
        }
    }
}
