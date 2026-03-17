import SwiftUI
import SwiftData
import CoreLocation

// These are the list items on the Collections page

struct CollectionListRowView: View {
    let collection: Collection
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

    var accentColor: Color {
        return InkwellTheme.collectionAccentColor(for: collection.colorHex)
    }
    var cardBackground: Color {
        InkwellTheme.collectionCardBackground(for: collection.colorHex)
    }

    var entryCount: Int {
        entries.filter { collectionMatches(entry: $0, collection: collection) }.count
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        style.usesSerifFonts
                        ? Circle().strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
                        : nil
                    )
                Image(systemName: collection.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(accentColor)
            }

            Text(collection.name)
                .font(style.body)
                .fontWeight(.medium)
                .foregroundStyle(style.primaryText)

            Spacer()

            HStack(spacing: 6) {
                Text("\(entryCount)")
                    .font(style.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            style.usesSerifFonts
            ? RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [InkwellTheme.cardBorderTop, accentColor.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
            : nil
        )
        .shadow(color: style.usesSerifFonts ? Color.black.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
    }
}
