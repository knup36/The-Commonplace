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
            if editMode.isEditing {
                statusSection
                    .padding(.top, 12)
            }
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
            
            // Status line — view mode only
            if !editMode.isEditing {
                let statuses: [(label: String, value: String, icon: String)] = [
                    ("To Play",  "wantTo",     "bookmark"),
                    ("Playing",  "inProgress", "gamecontroller.fill"),
                    ("Done",     "finished",   "checkmark.circle.fill"),
                    ("Re-Play",  "replay",     "arrow.clockwise.circle.fill")
                ]
                if let current = statuses.first(where: { $0.value == localStatus }) {
                    let color = mediaStatusColor(for: localStatus, theme: themeManager.current)
                    HStack(spacing: 5) {
                        Image(systemName: current.icon)
                            .font(style.typeBodySecondary)
                            .foregroundStyle(color)
                        Text(current.label)
                            .font(style.typeBodySecondary)
                            .foregroundStyle(color)
                    }
                }
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
            SlidingPillPicker(
                options: [
                    .init(label: "To Play",  value: "wantTo",     icon: "bookmark",              selectedColor: mediaStatusColor(for: "wantTo",     theme: themeManager.current)),
                    .init(label: "Playing",  value: "inProgress", icon: "gamecontroller",         selectedColor: mediaStatusColor(for: "inProgress", theme: themeManager.current)),
                    .init(label: "Done",     value: "finished",   icon: "checkmark.circle",       selectedColor: mediaStatusColor(for: "finished",   theme: themeManager.current)),
                    .init(label: "Re-Play",  value: "replay",     icon: "arrow.clockwise.circle", selectedColor: mediaStatusColor(for: "replay",     theme: themeManager.current))
                ],
                selection: $localStatus,
                accentColor: accentColor
            )
            .padding(.horizontal, 20)
            .onChange(of: localStatus) { _, _ in onStatusChange() }
        }
    }
