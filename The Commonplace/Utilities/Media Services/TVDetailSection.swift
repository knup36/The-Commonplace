// TVDetailSection.swift
// Commonplace
//
// Detail section for .media entries with mediaType == "tv".
// Displays cover art, locked metadata (title, year, genre, seasons),
// star rating, and watch status picker.
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
        VStack(spacing: 0) {
            coverArtHeader
            statusSection
                .padding(.top, 20)
        }
    }

    // MARK: - Cover Art Header

    var coverArtHeader: some View {
        HStack(alignment: .top, spacing: 16) {

            // Poster — rectangular 2:3
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 125, height: 188)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(style.cardDivider)
                        .frame(width: 125, height: 188)
                        .overlay(
                            Image(systemName: "tv.fill")
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

                if let year = entry.mediaYear, !year.isEmpty {
                    Text(year)
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }

                Text("Television Series")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(style.cardSecondaryText)

                if let genre = entry.mediaGenre, !genre.isEmpty {
                    Text(genre)
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }

                if let seasons = entry.mediaSeasons {
                    Text("\(seasons) \(seasons == 1 ? "Season" : "Seasons")")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
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
            ("Watchlist",   "wantTo",     "bookmark"),
            ("In Progress", "inProgress", "play.circle"),
            ("Finished",    "finished",   "checkmark.circle")
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
