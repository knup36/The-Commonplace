import SwiftUI
import SwiftData

struct CollectionCardView: View {
    let collection: Collection
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }
    
    var accentColor: Color { Color(hex: collection.colorHex) }
    var cardBackground: Color { accentColor.opacity(0.15) }
    
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
                .font(style.typeBodySecondary)
                .fontWeight(.semibold)
                .foregroundStyle(style.primaryText)
                .lineLimit(2)
            
            Text("\(entryCount) entries")
                .font(style.typeCaption)
                .foregroundStyle(style.tertiaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
        )
        .onDrag {
            NSItemProvider(object: collection.id.uuidString as NSString)
        }
    }
}
