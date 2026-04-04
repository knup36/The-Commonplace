// JournalPromptCard.swift
// Commonplace
//
// Displays the daily AI-generated journaling prompts on the Today tab.
// Appears above the journal block when all three emoji (weather, mood, vibe)
// have been set for the day.
//
// Two prompts are shown:
//   Reflect — introspective, philosophical
//   Act     — practical, grounded
//
// The card can be dismissed for the day via the X button.
// Dismissal state is managed by JournalPromptService.
//
// Loading state shows a subtle shimmer placeholder.
// Error state shows a gentle fallback message.

import SwiftUI

struct JournalPromptCard: View {
    let weather: String
    let mood: String
    let vibe: String

    @StateObject private var service = JournalPromptService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isDismissed = false

    var style: any AppThemeStyle { themeManager.style }
    var accent: Color { EntryType.journal.detailAccentColor(for: themeManager.current) }

    var body: some View {
        if !isDismissed {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("Today's Prompts")
                                            .font(style.typeBodySecondary)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(style.cardPrimaryText)
                    Spacer()
                    // Emoji summary
                    Text("\(weather) \(mood) \(vibe)")
                        .font(.caption)
                    // Dismiss button
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isDismissed = true
                            service.dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(style.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Divider()
                    .overlay(accent.opacity(0.2))

                // Content
                if service.isLoading {
                    loadingView
                } else if let prompt = service.prompt {
                    promptContent(prompt)
                } else if service.error != nil {
                    errorView
                }
            }
            .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(EntryType.journal.cardColor(for: themeManager.current))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(style.cardBorder, lineWidth: 0.5)
                                )
                        )
            .padding(.horizontal)
            .onAppear {
                isDismissed = service.isDismissedToday
                if !isDismissed && service.prompt == nil && !service.isLoading {
                    Task {
                        await service.fetchPrompt(weather: weather, mood: mood, vibe: vibe)
                    }
                }
            }
        }
    }

    // MARK: - Prompt Content

    func promptContent(_ prompt: JournalPrompt) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reflect section
            VStack(alignment: .leading, spacing: 6) {
                Label("Reflect", systemImage: "moon.stars")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(accent)
                Text(prompt.introspective)
                                    .font(style.typeBody)
                                    .foregroundStyle(style.cardPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .overlay(accent.opacity(0.15))
                .padding(.horizontal, 16)

            // Act section
            VStack(alignment: .leading, spacing: 6) {
                Label("Act", systemImage: "arrow.forward.circle")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(accent)
                Text(prompt.practical)
                                    .font(style.typeBody)
                                    .foregroundStyle(style.cardPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Loading View

    var loadingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accent.opacity(0.15))
                        .frame(width: 60, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(style.surface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(style.surface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(style.surface)
                        .frame(width: 200)
                        .frame(height: 10)
                }
            }
        }
        .padding(16)
        .opacity(0.7)
    }

    // MARK: - Error View

    var errorView: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(style.tertiaryText)
            Text("Couldn't load today's prompts. Check your connection.")
                .font(.caption)
                .foregroundStyle(style.tertiaryText)
        }
        .padding(16)
    }
}
