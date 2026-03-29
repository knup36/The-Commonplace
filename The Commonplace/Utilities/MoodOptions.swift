// MoodOptions.swift
// Commonplace
//
// Shared mood data used across JournalBlockView, mood picker, and insight cards.
// Each mood has an emoji, display label, and numerical score (1-10).
// Score is used to plot sentiment on the mood timeline insight card.
// Ordered from most positive to most negative.

import Foundation

struct MoodOption {
    let emoji: String
    let label: String
    let score: Int
    
    static let all: [MoodOption] = [
        MoodOption(emoji: "🤩", label: "Excited",              score: 10),
        MoodOption(emoji: "😄", label: "Joyful",               score: 10),
        MoodOption(emoji: "🧑‍🎨", label: "Creative",            score: 9),
        MoodOption(emoji: "💪", label: "Motivated",            score: 8),
        MoodOption(emoji: "🥹", label: "Proud",                score: 8),
        MoodOption(emoji: "😌", label: "Content",              score: 7),
        MoodOption(emoji: "☺️", label: "Thankful",             score: 6),
        MoodOption(emoji: "🤪", label: "Goofy",                score: 5),
        MoodOption(emoji: "🏃‍♂️", label: "Moving Like a Maniac", score: 5),
        MoodOption(emoji: "🫠", label: "Existential",          score: 5),
        MoodOption(emoji: "😒", label: "Lazy",                 score: 5),
        MoodOption(emoji: "🫤", label: "Meh",                  score: 4),
        MoodOption(emoji: "😣", label: "Tired",                score: 3),
        MoodOption(emoji: "🫨", label: "Anxious",              score: 3),
        MoodOption(emoji: "🙄", label: "Annoyed",              score: 3),
        MoodOption(emoji: "🫥", label: "Lonely",               score: 2),
        MoodOption(emoji: "😢", label: "Sad",                  score: 1),
        MoodOption(emoji: "😞", label: "Depressed",            score: 1),
    ]
    
    /// Look up a MoodOption by emoji string
    static func find(_ emoji: String) -> MoodOption? {
        all.first { $0.emoji == emoji }
    }
    
    /// Score for a given emoji, returns nil if not found
    static func score(for emoji: String) -> Int? {
        find(emoji)?.score
    }
    
    /// Label for a given emoji, returns nil if not found
    static func label(for emoji: String) -> String? {
        find(emoji)?.label
    }
}
