import SwiftUI
import SwiftData

struct PinnedCollectionsView: View {
    let collections: [Collection]
    @Binding var navigationPath: NavigationPath
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    let entries: [Entry]
    
    var isInkwell: Bool { themeManager.current == .inkwell }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(collections.sorted { $0.pinnedOrder < $1.pinnedOrder }) { collection in
                PinnedCollectionCell(
                    collection: collection,
                    entryCount: countEntries(for: collection),
                    navigationPath: $navigationPath,
                    onUnpin: { unpin(collection) }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
    
    func unpin(_ collection: Collection) {
        collection.isPinned = false
        let remaining = collections
            .filter { $0.isPinned && $0.id != collection.id }
            .sorted { $0.pinnedOrder < $1.pinnedOrder }
        for (index, col) in remaining.enumerated() {
            col.pinnedOrder = index
        }
    }
    
    func countEntries(for collection: Collection) -> Int {
        entries.filter { collectionMatches(entry: $0, collection: collection) }.count
    }
}

struct PinnedCollectionCell: View {
    let collection: Collection
    let entryCount: Int
    @Binding var navigationPath: NavigationPath
    let onUnpin: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var isInkwell: Bool { themeManager.current == .inkwell }
    var accentColor: Color {
        isInkwell
        ? InkwellTheme.collectionAccentColor(for: collection.colorHex)
        : Color(hex: collection.colorHex)
    }
    var body: some View {
        Button {
            navigationPath.append(collection)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isInkwell {
                        // Dark recessed base using collection's muted background
                        Circle()
                            .fill(InkwellTheme.collectionCardBackground(for: collection.colorHex))
                            .frame(width: 68, height: 68)
                        
                        // Rim matching entry/collection card border style
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [InkwellTheme.cardBorderTop, InkwellTheme.cardBorderTop.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .frame(width: 68, height: 68)
                        
                        // Icon in full vivid color for contrast against dark base
                        VStack(spacing: 3) {
                            Image(systemName: collection.icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(Color(hex: collection.colorHex))
                                .offset(y: 4)
                            Text("\(entryCount)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: collection.colorHex).opacity(0.8))
                                .offset(y: 6)
                        }
                        
                    } else {
                        Circle()
                            .fill(accentColor.opacity(0.2))
                            .frame(width: 68, height: 68)
                        VStack(spacing: 3) {
                            Image(systemName: collection.icon)
                                .font(.system(size: 26))
                                .foregroundStyle(accentColor)
                                .offset(y: 4)
                            Text("\(entryCount)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(accentColor)
                                .offset(y: 6)
                        }
                    }
                }
                Text(collection.name)
                    .font(isInkwell ? .system(.caption, design: .serif) : .caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { onUnpin() }
            } label: {
                Label("Unpin", systemImage: "pin.slash.fill")
            }
        }
    }
}
