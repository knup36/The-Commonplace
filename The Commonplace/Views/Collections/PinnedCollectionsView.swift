import SwiftUI
import SwiftData

// These are the pinned items on the Collections page

struct PinnedCollectionsView: View {
    let collections: [Collection]
    @Binding var navigationPath: NavigationPath
    @Environment(\.modelContext) var modelContext
    @Environment(\.editMode) var editMode
    @EnvironmentObject var themeManager: ThemeManager
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    let entries: [Entry]

    var style: any AppThemeStyle { themeManager.style }
    var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(collections.sorted { $0.pinnedOrder < $1.pinnedOrder }) { collection in
                let col = collection
                PinnedCollectionCell(
                    collection: col,
                    entryCount: countEntries(for: col),
                    navigationPath: $navigationPath,
                    isEditing: isEditing,
                    onUnpin: { unpin(col) }
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
    let isEditing: Bool
    let onUnpin: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color {
        InkwellTheme.collectionAccentColor(for: collection.colorHex)
    }

    var body: some View {
        Button {
            if !isEditing {
                navigationPath.append(collection)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    circleIcon
                    if isEditing {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                onUnpin()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .systemGray))
                                    .frame(width: 20, height: 20)
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .offset(x: -4, y: -4)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(collection.name)
                    .font(style.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditing)
    }

    var circleIcon: some View {
        ZStack {
            Circle()
                .fill(style.usesSerifFonts
                    ? InkwellTheme.collectionCardBackground(for: collection.colorHex)
                    : accentColor.opacity(0.2))
                .frame(width: 68, height: 68)
                .shadow(color: style.usesSerifFonts ? .black.opacity(0.4) : .clear, radius: 6, x: 0, y: 3)

            if style.usesSerifFonts {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [InkwellTheme.cardBorderTop, InkwellTheme.cardBorderTop.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                    .frame(width: 68, height: 68)
            }

            VStack(spacing: 3) {
                Image(systemName: collection.icon)
                    .font(.system(size: style.usesSerifFonts ? 24 : 26, weight: .medium))
                    .foregroundStyle(accentColor)
                    .offset(y: 4)
                Text("\(entryCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(style.usesSerifFonts ? 0.8 : 1.0))
                    .offset(y: 6)
            }
            .scaleEffect(isEditing ? 0.95 : 1.0)
        }
        .contentShape(Circle())
    }
}
