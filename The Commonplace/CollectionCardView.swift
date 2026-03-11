import SwiftUI
import SwiftData

struct CollectionCardView: View {
    let collection: Collection
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager

    var isInkwell: Bool { themeManager.current == .inkwell }
        var accentColor: Color {
            isInkwell
                ? InkwellTheme.collectionAccentColor(for: collection.colorHex)
                : Color(hex: collection.colorHex)
        }
        var cardBackground: Color {
            isInkwell
                ? InkwellTheme.collectionCardBackground(for: collection.colorHex)
                : Color(hex: collection.colorHex).opacity(0.1)
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
                .font(isInkwell ? .system(.subheadline, design: .serif) : .subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                .lineLimit(2)

            Text("\(entryCount) entries")
                .font(.caption)
                .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            isInkwell
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
        .shadow(color: isInkwell ? Color.black.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        .onDrag {
            NSItemProvider(object: collection.id.uuidString as NSString)
        }
    }
}
