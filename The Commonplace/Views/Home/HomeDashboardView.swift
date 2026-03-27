// HomeDashboardView.swift
// Commonplace
//
// Dashboard-style Home tab — a bookmarks dashboard.
// Shows only bookmarked items from each model type.
// Sections appear only when they have bookmarked content.
//
// Section order: Collections → Entries → People → Tags
//
// Shape system (per design language spec):
//   Collections — rounded square (app icon proportions)
//   Entries     — rounded rectangle (existing CompactEntryCard)
//   People      — circle with gold angular gradient ring
//   Tags        — pill / capsule with entry count
//
// Keep HomeView.swift around as fallback.

import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Query var allCollections: [Collection]
    @Query(sort: \Entry.createdAt, order: .reverse) var allEntries: [Entry]
    @Query var allTags: [Tag]
    @Query(sort: \Person.name) var allPersons: [Person]
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: any AppThemeStyle { themeManager.style }
    
    private let maxCards = 12
    private let twoRows = [GridItem(.fixed(100), spacing: 10), GridItem(.fixed(100), spacing: 10)]
    private let oneRow = [GridItem(.fixed(80))]
    private let entryRows = [GridItem(.fixed(80), spacing: 10), GridItem(.fixed(80), spacing: 10)]
    
    // MARK: - Filtered Data
    
    var pinnedCollections: [Collection] {
        allCollections
            .filter { $0.isPinned }
            .sorted { $0.pinnedOrder < $1.pinnedOrder }
    }
    
    var pinnedEntries: [Entry] {
        allEntries.filter { $0.isPinned }
    }
    
    var pinnedPersons: [Person] {
        allPersons.filter { $0.isPinned }
    }
    
    var pinnedTags: [Tag] {
        allTags
            .filter { $0.isPinned }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    var hasAnything: Bool {
        !pinnedCollections.isEmpty || !pinnedEntries.isEmpty ||
        !pinnedPersons.isEmpty || !pinnedTags.isEmpty
    }
    
    func entryCount(for collection: Collection) -> Int {
        allEntries.filter { collectionMatches(entry: $0, collection: collection) }.count
    }
    
    func entryCount(for tag: Tag) -> Int {
        allEntries.filter { $0.tagNames.contains(tag.name) }.count
    }
    
    func entryCount(for person: Person) -> Int {
        allEntries.filter { $0.tagNames.contains(person.tagString) }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    
                    // Title
                    Text("Home")
                        .font(style.usesSerifFonts
                              ? .system(size: 34, weight: .bold, design: .serif)
                              : .largeTitle.bold())
                        .foregroundStyle(style.primaryText)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    if !hasAnything {
                        emptyState
                    }
                    
                    // Collections section
                    if !pinnedCollections.isEmpty {
                        collectionsSection
                    }
                    
                    // Entries section
                    if !pinnedEntries.isEmpty {
                        entriesSection
                    }
                    
                    // People section
                    if !pinnedPersons.isEmpty {
                        peopleSection
                    }
                    
                    // Tags section
                    if !pinnedTags.isEmpty {
                        tagsSection
                    }
                    
                    Color.clear.frame(height: 50)
                }
            }
            .background(style.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(style.accent)
                    }
                }
            }
        }
    }
    
    // MARK: - Collections Section
    
    var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Collections", icon: "magazine.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: twoRows, spacing: 10) {
                    ForEach(pinnedCollections.prefix(maxCards)) { collection in
                        NavigationLink(destination: CollectionDetailView(collection: collection)) {
                            compactCollectionCard(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .scrollClipDisabled()
        }
    }
    
    func compactCollectionCard(collection: Collection) -> some View {
        let accent = Color(hex: collection.colorHex)
        let bg = InkwellTheme.collectionCardBackground(for: collection.colorHex)
        let count = entryCount(for: collection)
        
        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
                )
            
            VStack(spacing: 6) {
                Image(systemName: collection.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(InkwellTheme.collectionAccentColor(for: collection.colorHex))
                
                Text(collection.name)
                    .font(style.usesSerifFonts ? .system(.caption2, design: .serif) : .caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(style.tertiaryText)
            }
            .padding(8)
        }
        .frame(width: 100, height: 100)
        .shadow(color: style.usesSerifFonts ? .black.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Entries Section
    
    var entriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Bookmarks", icon: "bookmark.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(80), spacing: 10), GridItem(.fixed(80), spacing: 10)], spacing: 10) {
                    ForEach(pinnedEntries.prefix(maxCards)) { entry in
                        NavigationLink(destination: destinationView(for: entry)) {
                            CompactEntryCard(entry: entry, style: style)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }
    
    // MARK: - People Section
    
    var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "People", icon: "person.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: oneRow, spacing: 16) {
                    ForEach(pinnedPersons.prefix(maxCards)) { person in
                        NavigationLink(destination: PersonDetailView(person: person)) {
                            compactPersonCard(person: person)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .scrollClipDisabled()
        }
    }
    
    func compactPersonCard(person: Person) -> some View {
        VStack(spacing: 6) {
            // Avatar with gold angular gradient ring
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color(hex: "#C8903A"),
                                Color(hex: "#F5D478"),
                                Color(hex: "#C8903A"),
                                Color(hex: "#8A6028"),
                                Color(hex: "#C8903A"),
                                Color(hex: "#F5D478"),
                                Color(hex: "#C8903A")
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 58, height: 58)
                
                personAvatarView(person: person, size: 54)
            }
            
            // Name
            Text(person.name)
                .font(.caption2)
                .foregroundStyle(style.secondaryText)
                .lineLimit(1)
                .frame(width: 64)
        }
        .frame(width: 64, height: 80)
    }
    
    func personAvatarView(person: Person, size: CGFloat) -> some View {
        Group {
            if let path = person.profilePhotoPath,
               let data = MediaFileManager.load(path: path),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(style.accent.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.38, weight: .light))
                            .foregroundStyle(style.accent)
                    )
            }
        }
    }
    
    // MARK: - Tags Section
    
    var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Tags", icon: "tag.fill")
            
            // Wrapping pill layout — max 3 rows
            FlowLayout(spacing: 8, maxRows: 3) {
                ForEach(pinnedTags, id: \.name) { tag in
                    NavigationLink(destination: TagFeedView(tag: tag.name)) {
                        tagPill(tag: tag)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    func tagPill(tag: Tag) -> some View {
        let count = entryCount(for: tag)
        return HStack(spacing: 4) {
            Text(tag.name)
                .font(style.usesSerifFonts ? .system(.caption, design: .serif) : .caption)
                .italic(style.usesSerifFonts)
                .foregroundStyle(style.accent)
            Text("(\(count))")
                .font(.caption2)
                .foregroundStyle(style.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(style.accent.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(style.accent.opacity(0.25), lineWidth: 0.5)
        )
    }
    
    // MARK: - Section Header
    
    func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(style.accent)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(style.primaryText)
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Empty State
    
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 36))
                .foregroundStyle(style.tertiaryText)
            Text("Nothing bookmarked yet")
                .font(.headline)
                .foregroundStyle(style.secondaryText)
            Text("Bookmark entries, collections, tags, and people to see them here.")
                .font(.caption)
                .foregroundStyle(style.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 20)
    }
}

// MARK: - FlowLayout
// A simple wrapping layout for pill-style tags.
// Lays out children left to right, wrapping to new rows as needed.
// maxRows caps the number of rows shown.

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let maxRows: Int
    @ViewBuilder let content: Content
    
    var body: some View {
        _FlowLayout(spacing: spacing, maxRows: maxRows) {
            content
        }
    }
}

private struct _FlowLayout: Layout {
    let spacing: CGFloat
    let maxRows: Int
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, width: proposal.width ?? 0)
        let rows = min(result.rows, maxRows)
        let height = result.rowHeights.prefix(rows).reduce(0, +) + CGFloat(max(0, rows - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        var y = bounds.minY
        for (rowIndex, row) in result.rowItems.enumerated() {
            guard rowIndex < maxRows else { break }
            var x = bounds.minX
            for item in row {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += result.rowHeights[rowIndex] + spacing
        }
    }
    
    struct LayoutResult {
        var rows: Int
        var rowHeights: [CGFloat]
        var rowItems: [[(index: Int, size: CGSize)]]
    }
    
    func layout(subviews: Subviews, width: CGFloat) -> LayoutResult {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var rowWidths: [CGFloat] = [0]
        var rowHeights: [CGFloat] = [0]
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let currentRow = rows.count - 1
            let currentWidth = rowWidths[currentRow]
            
            if currentWidth + size.width + (currentWidth > 0 ? spacing : 0) > width && currentWidth > 0 {
                rows.append([(index: index, size: size)])
                rowWidths.append(size.width)
                rowHeights.append(size.height)
            } else {
                let addSpacing = currentWidth > 0 ? spacing : 0
                rows[currentRow].append((index: index, size: size))
                rowWidths[currentRow] += size.width + addSpacing
                rowHeights[currentRow] = max(rowHeights[currentRow], size.height)
            }
        }
        
        return LayoutResult(rows: rows.count, rowHeights: rowHeights, rowItems: rows)
    }
}
