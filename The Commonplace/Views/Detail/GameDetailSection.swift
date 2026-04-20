// GameDetailSection.swift
// Commonplace
//
// Detail section for .media entries with mediaType == "game".
// Displays a 16:9 hero image (RAWG background_image is landscape),
// title, year, platforms, developer, star rating, and play status picker.
//
// Consumed by MediaDetailView inside populatedView.
// Requires EditModeManager via @EnvironmentObject.

import SwiftUI

struct GameDetailSection: View {
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
        VStack(spacing: 0) {
            heroImageHeader
            metadataSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            statusSection
                .padding(.top, 12)
        }
    }

    // MARK: - Hero Image

    var heroImageHeader: some View {
        Group {
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(style.cardDivider)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(style.cardSecondaryText)
                    )
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Metadata

    var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = entry.mediaTitle {
                            Text(title)
                                .font(style.typeTitle2)
                                .fontWeight(.bold)
                                .foregroundStyle(style.cardPrimaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

            if let year = entry.mediaYear, !year.isEmpty {
                Text(year)
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.cardSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let platform = entry.mediaPlatform, !platform.isEmpty {
                Text(platform)
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let developer = entry.mediaOverview, !developer.isEmpty {
                Text(developer)
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.cardSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Star rating
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: localRating >= star ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundStyle(localRating >= star ? .yellow : style.cardMetadataText)
                        .onTapGesture {
                            guard editMode.isEditing else { return }
                            localRating = localRating == star ? 0 : star
                            onStatusChange()
                        }
                }
            }
            .transaction { $0.animation = nil }
            .padding(.top, 4)
        }
    }

    // MARK: - Status Section

    var statusSection: some View {
        let statuses: [(label: String, value: String, icon: String)] = [
                    ("To Play",  "wantTo",     "bookmark"),
                    ("Playing",  "inProgress", "gamecontroller"),
                    ("Done",     "finished",   "checkmark.circle"),
                    ("Re-Play",  "replay",     "arrow.clockwise.circle")
                ]
        return HStack(spacing: 0) {
            ForEach(statuses, id: \.value) { item in
                let isSelected = localStatus == item.value
                let color = mediaStatusColor(for: item.value, theme: themeManager.current)
                let inactiveColor = accentColor
                Button {
                    guard editMode.isEditing else { return }
                    localStatus = item.value
                    onStatusChange()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isSelected ? "\(item.icon).fill" : item.icon)
                            .font(style.typeCaption)
                        Text(item.label)
                            .font(style.typeLabel)
                    }
                    .foregroundStyle(isSelected ? color : inactiveColor.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(isSelected ? color.opacity(0.15) : Color.clear)
                }
                .buttonStyle(.plain)
                if item.value != "replay" {
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
