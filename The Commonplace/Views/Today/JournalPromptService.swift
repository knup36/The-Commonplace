// JournalPromptService.swift
// Commonplace
//
// Fetches a personalized daily journaling prompt from the Claude API
// based on the user's weather, mood, and vibe emoji for today.
//
// Privacy note:
//   Only three emoji characters are ever sent to the API.
//   No journal text, entry content, or personal information leaves the device.
//
// Caching:
//   Prompts are cached in UserDefaults keyed to today's date string.
//   On subsequent app opens the cached prompt is served instantly — no API call.
//   Cache is automatically invalidated at midnight when the date changes.
//
// Dismissal:
//   When the user dismisses the card, today's date is stored.
//   The card will not reappear until tomorrow.
//
// Response format:
//   Claude is instructed to return a JSON object with two fields:
//   { "introspective": "...", "practical": "..." }

import Foundation
import Combine

struct JournalPrompt {
    let introspective: String
    let practical: String
}

class JournalPromptService: ObservableObject {

    static let shared = JournalPromptService()

    @Published var prompt: JournalPrompt? = nil
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let cacheKey = "journalPrompt_cached"
    private let cacheDateKey = "journalPrompt_cachedDate"
    private let dismissedDateKey = "journalPrompt_dismissedDate"

    private let apiKey = "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"
    private let model = "claude-sonnet-4-20250514"

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Public Interface

    /// Returns true if the card should be shown today.
    /// False if the user already dismissed it today.
    var isDismissedToday: Bool {
        UserDefaults.standard.string(forKey: dismissedDateKey) == todayString
    }

    /// Dismiss the prompt card for today.
    func dismiss() {
        UserDefaults.standard.set(todayString, forKey: dismissedDateKey)
    }

    /// Fetch a prompt for today's emoji combination.
    /// Serves from cache if already fetched today, otherwise calls the API.
    func fetchPrompt(weather: String, mood: String, vibe: String) async {
        // Check cache first
        if let cached = cachedPromptForToday() {
            await MainActor.run {
                self.prompt = cached
            }
            return
        }

        await MainActor.run { self.isLoading = true }

        let systemPrompt = """
        You are a thoughtful journaling companion. Given three emoji that represent someone's weather, mood, and vibe for the day, generate two short journaling prompts:
        
        1. "introspective" — a reflective, philosophical prompt that invites inner exploration. 1-2 sentences.
        2. "practical" — a grounded, actionable prompt that encourages doing or noticing something concrete. 1-2 sentences.
        
        The prompts should feel personal and warm, as if written by a wise friend who noticed the emoji combination.
        Draw meaning from the combination — not just each emoji individually.
        
        Respond ONLY with a valid JSON object in this exact format, no preamble, no markdown:
        {"introspective": "...", "practical": "..."}
        """

        let userMessage = "Weather: \(weather) | Mood: \(mood) | Vibe: \(vibe)"

        do {
            let response = try await callClaudeAPI(systemPrompt: systemPrompt, userMessage: userMessage)
            let parsed = try parsePrompt(from: response)
            cachePrompt(parsed)
            await MainActor.run {
                self.prompt = parsed
                self.isLoading = false
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = "Couldn't fetch today's prompt."
            }
        }
    }

    // MARK: - API Call

    private func callClaudeAPI(systemPrompt: String, userMessage: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw PromptError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PromptError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String

        guard let text else { throw PromptError.parseError }
        return text
    }

    // MARK: - Parsing

    private func parsePrompt(from text: String) throws -> JournalPrompt {
        let clean = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = clean.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let introspective = json["introspective"] as? String,
              let practical = json["practical"] as? String else {
            throw PromptError.parseError
        }

        return JournalPrompt(introspective: introspective, practical: practical)
    }

    // MARK: - Caching

    private func cachedPromptForToday() -> JournalPrompt? {
        guard UserDefaults.standard.string(forKey: cacheDateKey) == todayString,
              let data = UserDefaults.standard.data(forKey: cacheKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let introspective = json["introspective"],
              let practical = json["practical"] else {
            return nil
        }
        return JournalPrompt(introspective: introspective, practical: practical)
    }

    private func cachePrompt(_ prompt: JournalPrompt) {
        let dict: [String: String] = [
            "introspective": prompt.introspective,
            "practical": prompt.practical
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(todayString, forKey: cacheDateKey)
        }
    }

    // MARK: - Errors

    enum PromptError: Error {
        case invalidURL
        case apiError
        case parseError
    }
}
