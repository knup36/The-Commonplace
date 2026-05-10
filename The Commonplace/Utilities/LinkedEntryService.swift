// LinkedEntryService.swift
// Commonplace
//
// Manages all linked entry operations for the v3.0 Linked Entries feature.
//
// Responsibilities:
//   - Creating bidirectional links between two entries
//   - Removing bidirectional links between two entries
//   - Scrubbing all links for a deleted entry
//   - Computing ranked link suggestions for the Connect sheet
//
// Architecture notes:
//   - Static struct — no instance needed, matches GiftCardService pattern
//   - All mutations touch both entries simultaneously and save once
//   - Both entries must be in the same ModelContext (always true in this app)
//   - Never call from a detached Task — ModelContext is not Sendable
//   - Suggestion algorithm is pure in-memory — full archive fetch owned by ConnectPageSheet
//   - removeAllLinks uses a targeted UUID-based FetchDescriptor — never queries full archive
//
// Bidirectionality invariant:
//   If entry A's linkedEntryIDs contains B's id, then B's linkedEntryIDs
//   contains A's id. This is always enforced by this service and never
//   managed directly from a view.

import SwiftData
import Foundation

struct LinkedEntryService {

    // MARK: - Link

    /// Creates a bidirectional link between two entries.
    /// Adds each entry's UUID to the other's `linkedEntryIDs`.
    /// No-op if the link already exists.
    /// Calls `touch()` on both entries and saves once.
    static func link(_ entryA: Entry, to entryB: Entry, context: ModelContext) {
        let idA = entryA.id.uuidString
        let idB = entryB.id.uuidString

        guard idA != idB else { return }

        let alreadyLinked = entryA.linkedEntryIDs.contains(idB)
        guard !alreadyLinked else { return }

        entryA.linkedEntryIDs.append(idB)
        entryB.linkedEntryIDs.append(idA)

        entryA.touch()
        entryB.touch()

        try? context.save()
    }

    // MARK: - Unlink

    /// Removes a bidirectional link between two entries.
    /// Removes each entry's UUID from the other's `linkedEntryIDs`.
    /// No-op if no link exists.
    /// Calls `touch()` on both entries and saves once.
    static func unlink(_ entryA: Entry, from entryB: Entry, context: ModelContext) {
        let idA = entryA.id.uuidString
        let idB = entryB.id.uuidString

        entryA.linkedEntryIDs.removeAll { $0 == idB }
        entryB.linkedEntryIDs.removeAll { $0 == idA }

        entryA.touch()
        entryB.touch()

        try? context.save()
    }

    // MARK: - Remove All Links (on entry deletion)

    /// Scrubs all links for an entry that is about to be deleted.
    /// Fetches only the specific entries referenced in `linkedEntryIDs`
    /// by UUID — never queries the full archive.
    /// Saves once after all mutations.
    ///
    /// Call this immediately before deleting the entry from the context.
    static func removeAllLinks(for entry: Entry, context: ModelContext) {
        let deletedID = entry.id.uuidString

        guard !entry.linkedEntryIDs.isEmpty else { return }

        // Fetch only the affected entries by UUID — targeted, not full archive
        let linkedUUIDs = entry.linkedEntryIDs.compactMap { UUID(uuidString: $0) }

        var descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { linkedUUIDs.contains($0.id) }
        )
        descriptor.fetchLimit = linkedUUIDs.count

        guard let affectedEntries = try? context.fetch(descriptor) else { return }

        for other in affectedEntries {
            other.linkedEntryIDs.removeAll { $0 == deletedID }
            other.touch()
        }

        try? context.save()
    }

    // MARK: - Suggestions

    /// Returns ranked link suggestions for the Connect sheet.
    ///
    /// Ranking (in priority order):
    ///   1. Tag overlap — count of shared tagNames with the current entry
    ///   2. Link frequency — total number of existing links (linkedEntryIDs.count)
    ///   3. Recency — createdAt descending
    ///
    /// Exclusions:
    ///   - The current entry itself
    ///   - Entries already linked to the current entry
    ///   - When the current entry has tags: entries with zero tag overlap
    ///     AND zero existing links are excluded (too weak a signal)
    ///
    /// Fallback: if fewer than `limit` candidates remain after ranking,
    /// fills remaining slots with the most recently created entries
    /// not already in the list and not already linked.
    static func suggestions(for entry: Entry, allEntries: [Entry], limit: Int = 5) -> [Entry] {
        let currentID = entry.id.uuidString
        let currentTagSet = Set(entry.tagNames)
        let linkedIDSet = Set(entry.linkedEntryIDs)
        let entryHasTags = !currentTagSet.isEmpty

        // Build ranked candidates
        var candidates: [(entry: Entry, tagOverlap: Int, linkCount: Int)] = []

        for candidate in allEntries {
            let candidateID = candidate.id.uuidString

            // Exclude self
            guard candidateID != currentID else { continue }

            // Exclude already-linked entries
            guard !linkedIDSet.contains(candidateID) else { continue }

            let tagOverlap = Set(candidate.tagNames).intersection(currentTagSet).count
            let linkCount = candidate.linkedEntryIDs.count

            // When the current entry has tags, exclude candidates with no signal at all
            if entryHasTags && tagOverlap == 0 && linkCount == 0 { continue }

            candidates.append((entry: candidate, tagOverlap: tagOverlap, linkCount: linkCount))
        }

        // Sort by tag overlap desc, then link frequency desc, then recency desc
        candidates.sort {
            if $0.tagOverlap != $1.tagOverlap {
                return $0.tagOverlap > $1.tagOverlap
            }
            if $0.linkCount != $1.linkCount {
                return $0.linkCount > $1.linkCount
            }
            return $0.entry.createdAt > $1.entry.createdAt
        }

        var results = Array(candidates.prefix(limit).map { $0.entry })

        // Fallback: fill remaining slots with most recent entries not already included
        if results.count < limit {
            let resultIDs = Set(results.map { $0.id.uuidString })

            let fallbacks = allEntries
                .filter {
                    $0.id.uuidString != currentID &&
                    !linkedIDSet.contains($0.id.uuidString) &&
                    !resultIDs.contains($0.id.uuidString)
                }
                .sorted { $0.createdAt > $1.createdAt }

            let needed = limit - results.count
            results.append(contentsOf: fallbacks.prefix(needed))
        }

        return results
    }

    // MARK: - Shared Tag Label

    /// Returns the single most-shared tag name between a candidate entry
    /// and the current entry. Used in the Connect sheet subtitle.
    /// Returns nil if there is no tag overlap.
    static func topSharedTag(between entry: Entry, and candidate: Entry) -> String? {
        let currentTags = Set(entry.tagNames)
        let sharedTags = Set(candidate.tagNames).intersection(currentTags)
        return sharedTags.sorted().first
    }
}
