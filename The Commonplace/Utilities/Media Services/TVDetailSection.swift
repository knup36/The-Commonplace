// TVDetailSection.swift
// Commonplace
//
// Detail section for .media entries with mediaType == "tv".
// Redesigned v2.4 — centered poster hero with accent glow,
// bold title below, metadata hierarchy, centered star rating,
// 4-status picker (Watchlist · Watching · Done · Re-Watch).
// Takes design cues from MusicDetailSection.
//
// Consumed by MediaDetailView inside populatedView.
// Requires EditModeManager via @EnvironmentObject.

import SwiftUI

struct TVDetailSection: View {
    @Bindable var entry: Entry
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var editMode: EditModeManager
    
    var coverImage: UIImage?
    @Binding var localRating: Int
    @Binding var localStatus: String
    var onStatusChange: () -> Void
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color { entry.type.detailAccentColor(for: themeManager.current) }
    
    var body: some View {
        VStack(spacing: 20) {
            posterHero
            metadataBlock
            starRating
            if editMode.isEditing {
                statusSection
            }
        }
    }
    
    // MARK: - Poster Hero
    
    var posterHero: some View {
        ZStack {
            if coverImage != nil {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 160, height: 240)
                    .blur(radius: 20)
            }
            
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: accentColor.opacity(0.15), radius: 10, x: 0, y: 5)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(style.cardDivider)
                        .frame(width: 160, height: 240)
                        .overlay(
                            Image(systemName: "tv.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(accentColor.opacity(0.4))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 20)
    }
    
    // MARK: - Metadata
    
    var metadataBlock: some View {
        VStack(spacing: 6) {
            if let title = entry.mediaTitle {
                Text(title)
                    .font(style.typeTitle1)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.cardPrimaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            metaLine
                .frame(maxWidth: .infinity, alignment: .center)
            if !editMode.isEditing {
                statusLine
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if let overview = entry.mediaOverview, !overview.isEmpty {
                Text(overview)
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.cardSecondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    var metaLine: some View {
        let parts: [String] = [
            entry.mediaYear.flatMap { $0.isEmpty ? nil : $0 },
            "TV Series",
            entry.mediaGenre.flatMap { $0.isEmpty ? nil : $0 },
            entry.mediaSeasons.map { "\($0) \($0 == 1 ? "Season" : "Seasons")" }
        ].compactMap { $0 }
        
        return Text(parts.joined(separator: " · "))
            .font(style.typeBodySecondary)
            .foregroundStyle(style.cardSecondaryText)
            .multilineTextAlignment(.center)
    }
    
    var statusLine: some View {
        let statuses: [(label: String, value: String, icon: String)] = [
            ("Watchlist", "wantTo",     "bookmark"),
            ("Watching",  "inProgress", "play.circle.fill"),
            ("Done",      "finished",   "checkmark.circle.fill"),
            ("Re-Watch",  "rewatch",    "arrow.clockwise.circle.fill")
        ]
        let current = statuses.first { $0.value == localStatus }
        ?? statuses[0]
        let color = mediaStatusColor(for: localStatus, theme: themeManager.current)
        
        return HStack(spacing: 5) {
            Image(systemName: current.icon)
                .font(style.typeBodySecondary)
                .foregroundStyle(color)
            Text(current.label)
                .font(style.typeBodySecondary)
                .foregroundStyle(color)
        }
    }
    // MARK: - Star Rating
    
    var starRating: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: localRating >= star ? "star.fill" : "star")
                    .font(.system(size: 22))
                    .foregroundStyle(localRating >= star ? .yellow : style.cardMetadataText)
                    .onTapGesture {
                        guard editMode.isEditing else { return }
                        localRating = localRating == star ? 0 : star
                        onStatusChange()
                    }
            }
        }
        .transaction { $0.animation = nil }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Status Section
    
    var statusSection: some View {
        let statuses: [(label: String, value: String, icon: String)] = [
            ("Watchlist", "wantTo",     "bookmark"),
            ("Watching",  "inProgress", "play.circle"),
            ("Done",      "finished",   "checkmark.circle"),
            ("Re-Watch",  "rewatch",    "arrow.clockwise.circle")
        ]
        return HStack(spacing: 0) {
            ForEach(statuses, id: \.value) { item in
                let isSelected = localStatus == item.value
                let color = mediaStatusColor(for: item.value, theme: themeManager.current)
                Button {
                    guard editMode.isEditing else { return }
                    localStatus = item.value
                    onStatusChange()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: isSelected ? "\(item.icon).fill" : item.icon)
                            .font(style.typeCaption)
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(isSelected ? color : accentColor.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? color.opacity(0.15) : Color.clear)
                }
                .buttonStyle(.plain)
                if item.value != "rewatch" {
                    Divider()
                        .frame(height: 16)
                        .overlay(style.tertiaryText.opacity(0.3))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }
}
