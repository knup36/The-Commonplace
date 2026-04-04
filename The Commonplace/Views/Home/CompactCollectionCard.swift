// CompactCollectionCard.swift
// Commonplace
//
// Compact card for collections shown in HomeDashboardView.
// Displays collection icon, name, and entry count.
// Same dimensions as CompactEntryCard (160×120pts).

import SwiftUI

struct CompactCollectionCard: View {
    let collection: Collection
    let entryCount: Int
    var style: any AppThemeStyle
    
    private let cardWidth: CGFloat = 160
    private let cardHeight: CGFloat = 80
    
    var accentColor: Color {
        Color(hex: collection.colorHex)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(accentColor.opacity(0.25), lineWidth: 0.5)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(style.typeCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(2)
                Text("\(entryCount) \(entryCount == 1 ? "entry" : "entries")")
                    .font(style.typeCaption)
                    .foregroundStyle(style.secondaryText)
            }
            .padding(12)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
}

// MARK: - CompactTagCard
// Compact card for tags shown in HomeDashboardView.
// Displays tag name and entry count.
// Same dimensions as other compact cards (160×120pts).

struct CompactTagCard: View {
    let tag: Tag
    let entryCount: Int
    var style: any AppThemeStyle
    
    private let cardWidth: CGFloat = 160
    private let cardHeight: CGFloat = 80
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(style.accent.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style.accent.opacity(0.25), lineWidth: 0.5)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(tag.name)
                    .font(style.typeCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(2)
                Text("\(entryCount) \(entryCount == 1 ? "entry" : "entries")")
                    .font(style.typeCaption)
                    .foregroundStyle(style.secondaryText)
            }
            .padding(12)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
}
