import SwiftUI
import SwiftData

struct CollectionCardView: View {
    let collection: Collection
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }

    var accentColor: Color {
        InkwellTheme.collectionAccentColor(for: collection.colorHex)
    }
    var cardBackground: Color {
        InkwellTheme.collectionCardBackground(for: collection.colorHex)
    }

    var entryCount: Int {
        entries.filter { collectionMatches(entry: $0, collection: collection) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: collection.icon)
                .font(.title2)
                .foregroundStyle(accentColor)

            Spacer()

            Text(collection.name)
                .font(style.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(style.primaryText)
                .lineLimit(2)

            Text("\(entryCount) entries")
                .font(style.caption)
                .foregroundStyle(style.tertiaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
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
        .onDrag {
            NSItemProvider(object: collection.id.uuidString as NSString)
        }
    }
}
