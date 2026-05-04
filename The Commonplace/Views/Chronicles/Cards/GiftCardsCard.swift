// GiftCardsCard.swift
// Commonplace
//
// Chronicles card showing the last 10 Gift Cards that have fired.
// Read-only archive — no dismissal, newest first.
// Uses ChroniclesCardContainer with .parchment background (silver/slate).
//
// Hides entirely when the archive is empty.

import SwiftUI

struct GiftCardsCard: View {
    var style: any AppThemeStyle
    let allEntries: [Entry]
    @State private var archive: [GiftCardRecord] = []
    
    var body: some View {
        ChroniclesCardContainer(
            title: "Gift Cards",
            icon: "gift",
            cardID: "giftCards",
            background: .parchment
        ) {
            if archive.isEmpty {
                Text("Gift Cards will appear here as Commonplace notices things worth surfacing.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(archive) { record in
                        archiveRow(record: record)
                        if record.id != archive.last?.id {
                            Divider()
                                .overlay(ChroniclesTheme.sectionDivider)
                                .padding(.leading, 36)
                        }
                    }
                }
            }
        }
        .onAppear {
            archive = GiftCardService.loadArchive()
        }
    }
    
    @ViewBuilder
    func lookupEntry(for record: GiftCardRecord) -> Entry? {
            guard let uuid = UUID(uuidString: record.entryID) else { return nil }
            return allEntries.first { $0.id == uuid }
        }
    
    func archiveRow(record: GiftCardRecord) -> some View {
            let isComingSoon = record.cardType == GiftCardType.comingSoon.rawValue
            let accentColor: Color = isComingSoon ? .orange : (lookupEntry(for: record)?.type.accentColor(for: .inkwell) ?? .white)

            let rowContent = HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: record.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accentColor.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(style.typeBodySecondary)
                        .foregroundStyle(ChroniclesTheme.primaryText)
                        .lineLimit(1)
                    Text(record.message)
                        .font(style.typeCaption)
                        .foregroundStyle(ChroniclesTheme.secondaryText)
                        .lineLimit(2)
                    Text(record.firedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(style.typeCaption)
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.top, 1)
                }

                Spacer()

                if !isComingSoon, lookupEntry(for: record) != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ChroniclesTheme.tertiaryText)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())

            if !isComingSoon, let entry = lookupEntry(for: record) {
                return AnyView(NavigationLink(value: entry) { rowContent }.buttonStyle(.plain))
            } else {
                return AnyView(rowContent)
            }
        }
}

