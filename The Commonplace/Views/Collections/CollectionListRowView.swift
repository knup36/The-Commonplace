import SwiftUI
import SwiftData
import CoreLocation

// These are the list items on the Collections page

struct CollectionListRowView: View {
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
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(isInkwell ? 0.15 : 0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        isInkwell
                        ? Circle().strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
                        : nil
                    )
                Image(systemName: collection.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(accentColor)
            }

            // Name
            Text(collection.name)
                .font(isInkwell ? .system(.body, design: .serif) : .body)
                .fontWeight(.medium)
                .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)

            Spacer()

            // Entry count + chevron
            HStack(spacing: 6) {
                Text("\(entryCount)")
                    .font(.subheadline)
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
    }
}
