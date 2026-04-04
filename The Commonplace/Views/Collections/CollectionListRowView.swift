import SwiftUI
import SwiftData
import CoreLocation

// These are the list items on the Collections page

struct CollectionListRowView: View {
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
                    )
                Image(systemName: collection.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(accentColor)
            }
            
            Text(collection.name)
                .font(style.typeBody)
                .fontWeight(.medium)
                .foregroundStyle(style.primaryText)
            
            Spacer()
            
            HStack(spacing: 6) {
                Text("\(entryCount)")
                    .font(style.typeBodySecondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                Image(systemName: "chevron.right")
                    .font(style.typeCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
        )
    }
}
