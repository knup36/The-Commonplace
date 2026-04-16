// PodcastDetailSection.swift
// Commonplace
//
// Detail section for .media entries with mediaType == "podcast".
// Displays artwork, locked metadata (title, publisher, genre, website),
// star rating, and listen status picker.
//
// Consumed by MediaDetailView inside populatedView.
// Requires EditModeManager via @EnvironmentObject.

import SwiftUI

struct PodcastDetailSection: View {
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
            artworkHeader
            statusSection
                .padding(.top, 20)
        }
    }

    // MARK: - Artwork Header

    var artworkHeader: some View {
        HStack(alignment: .top, spacing: 16) {

            // Artwork — square
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 125, height: 125)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(style.cardDivider)
                        .frame(width: 125, height: 125)
                        .overlay(
                            Image(systemName: "mic.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(style.cardSecondaryText)
                        )
                }
            }

            // Metadata column
            VStack(alignment: .leading, spacing: 5) {
                if let title = entry.mediaTitle {
                    Text(title)
                        .font(style.typeTitle3)
                        .fontWeight(.bold)
                        .foregroundStyle(style.cardPrimaryText)
                        .lineLimit(3)
                }

                Spacer().frame(height: 4)

                // Publisher stored in mediaGenre field
                if let publisher = entry.mediaOverview, !publisher.isEmpty {
                    Text(publisher)
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                        .lineLimit(2)
                }

                Text("Podcast")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.cardSecondaryText)

                if let genre = entry.mediaGenre, !genre.isEmpty {
                    Text(genre)
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }

                // Website link
                if let urlString = entry.url,
                   let url = URL(string: urlString),
                   !urlString.isEmpty {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "safari")
                                .font(.system(size: 11))
                            Text("Open in Podcasts")
                                .font(style.typeCaption)
                        }
                        .foregroundStyle(accentColor)
                    }
                }

                Spacer().frame(height: 4)

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
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Status Section

    var statusSection: some View {
        let statuses: [(label: String, value: String, icon: String)] = [
            ("Want to Listen", "wantTo",     "bookmark"),
            ("Listening",      "inProgress", "headphones"),
            ("Finished",       "finished",   "checkmark.circle")
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
                if item.value != "finished" {
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
