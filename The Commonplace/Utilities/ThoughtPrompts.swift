// ThoughtPrompts.swift
// Commonplace
//
// Curated prompts displayed in the Thought capture bar in FeedView.
// Prompts rotate randomly on each app launch and are organised by category.
//
// Adding new prompts:
//   - Add to the appropriate category array below
//   - No other changes needed — ThoughtPrompts.all picks them up automatically
//
// Categories:
//   Observational — things noticed in the world
//   Reflective    — inner state, patterns, self-awareness
//   Opinionated   — beliefs, disagreements, convictions
//   Curious       — questions, unknowns, things worth exploring
//   Creative      — imagination, making, expression
//   Connective    — people, relationships, conversations

import Foundation

enum ThoughtPrompts {

    static let observational: [String] = [
        "What did you notice today?",
        "What made you look twice?",
        "What surprised you?",
        "What's something you finally really saw?",
        "What detail stuck with you?",
        "What did the light look like today?",
        "What sound do you keep hearing?",
        "What felt different today?"
    ]

    static let reflective: [String] = [
        "What are you sitting with?",
        "What keeps coming back to you?",
        "What do you want to remember about today?",
        "What would you tell yourself from a year ago?",
        "What are you pretending not to know?",
        "What feeling are you not naming yet?",
        "What has this week taught you?",
        "What are you slowly figuring out?"
    ]

    static let opinionated: [String] = [
        "What do you disagree with?",
        "What's overrated?",
        "What changed your mind recently?",
        "What's a hill you'll die on?",
        "What are you done apologizing for?",
        "What's an opinion you've never said out loud?",
        "What's wrong with how everyone does it?",
        "What do you know that most people don't?"
    ]

    static let curious: [String] = [
        "What are you wondering about?",
        "What don't you understand yet?",
        "What would you look up if you had time?",
        "What question do you keep avoiding?",
        "What would you study if it didn't have to be useful?",
        "What do you want to know more about?",
        "What's a mystery you keep coming back to?",
        "What's something you've always assumed but never verified?"
    ]

    static let creative: [String] = [
        "What would you make if no one was watching?",
        "What's a story only you could tell?",
        "What image keeps appearing in your mind?",
        "What would you build if you had a year and no budget?",
        "What's a title without a book yet?",
        "What would the soundtrack to today sound like?",
        "What color is your mood right now?",
        "What wants to be made?"
    ]

    static let connective: [String] = [
        "Who have you been thinking about?",
        "What reminded you of someone today?",
        "Who do you want to call but haven't?",
        "What would you want someone to know about you right now?",
        "Who shaped how you think?",
        "What conversation are you still having in your head?",
        "Who deserves more credit than they get?",
        "What would you say if you knew they'd understand?"
    ]

    /// All prompts combined — used for random selection
    static let all: [String] = observational + reflective + opinionated + curious + creative + connective

    /// Returns a random prompt, optionally avoiding the current one
    static func random(avoiding current: String? = nil) -> String {
        let pool = current.map { c in all.filter { $0 != c } } ?? all
        return pool.randomElement() ?? all[0]
    }
}
