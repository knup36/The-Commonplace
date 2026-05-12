// iPadHomeView.swift
// Commonplace
//
// iPad Home tab — content column of NavigationSplitView.
//
// Owns a NavigationStack that navigates internally — mirrors iPadLibraryView
// pattern exactly. Does NOT embed HomeDashboardView to avoid nested
// NavigationStack conflicts.
//
// Root: bookmarks dashboard (collections, folios, entries, people, tags)
// Push: CollectionDetailView, PersonDetailView, TagFeedView
//
// selectedEntry is owned by iPadRootView and passed as a Binding.
// Tapping a bookmarked Entry drives iPadEntryDetailPanel directly.
// Tapping a Collection/Folio/Person/Tag pushes into the content column.
// Tapping an entry inside any pushed feed drives the detail panel.
//
// iPhone: completely unaffected — ContentView still shows HomeDashboardView.

import SwiftUI
import SwiftData

struct iPadHomeView: View {
    @Binding var selectedEntry: Entry?

    @Query var allCollections: [Collection]
    @Query(sort: \Entry.createdAt, order: .reverse) var allEntries: [Entry]
    @Query var allTags: [Tag]
    @Query var allPersonTags: [Tag]
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) var modelContext

    @State private var navigationPath = NavigationPath()

    var style: any AppThemeStyle { themeManager.style }

    private let maxCards = 12
    private let twoRows = [GridItem(.fixed(100), spacing: 10), GridItem(.fixed(100), spacing: 10)]
    private let oneRow = [GridItem(.fixed(80))]

    // MARK: - Filtered Data

    var allPersons: [Tag] {
        allPersonTags.filter { $0.isPerson }.sorted { $0.name < $1.name }
    }

    var pinnedCollections: [Collection] {
        allCollections
            .filter { $0.isPinned && !$0.isFolio }
            .sorted { $0.pinnedOrder < $1.pinnedOrder }
    }

    var pinnedEntries: [Entry] {
        allEntries.filter { $0.isPinned }
    }

    var pinnedPersons: [Tag] {
        allPersons.filter { $0.isPinned }
    }

    var pinnedFolios: [Collection] {
        allCollections
            .filter { $0.isPinned && $0.isFolio }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var pinnedTags: [Tag] {
        allTags
            .filter { $0.isPinned && !$0.isFolio && !$0.isPerson }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var hasAnything: Bool {
        !pinnedCollections.isEmpty || !pinnedEntries.isEmpty ||
        !pinnedPersons.isEmpty || !pinnedTags.isEmpty || !pinnedFolios.isEmpty
    }

    func entryCount(for collection: Collection) -> Int {
        allEntries.filter { collectionMatches(entry: $0, collection: collection) }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    Text("Home")
                        .font(style.typeLargeTitle)
                        .foregroundStyle(style.primaryText)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if !hasAnything {
                        emptyState
                    }

                    if !pinnedCollections.isEmpty { collectionsSection }
                    if !pinnedFolios.isEmpty { foliosSection }
                    if !pinnedEntries.isEmpty { entriesSection }
                    if !pinnedPersons.isEmpty { peopleSection }
                    if !pinnedTags.isEmpty { tagsSection }

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
            // MARK: - Navigation destinations
            .navigationDestination(for: Collection.self) { collection in
                CollectionDetailView(
                    collection: collection,
                    onSelectEntry: { entry in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedEntry = entry
                        }
                    }
                )
            }
            .navigationDestination(for: Tag.self) { tag in
                PersonDetailView(
                    tag: tag,
                    onSelectEntry: { entry in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedEntry = entry
                        }
                    }
                )
            }
            .navigationDestination(for: String.self) { tagName in
                TagFeedView(
                    tag: tagName,
                    onSelectEntry: { entry in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedEntry = entry
                        }
                    }
                )
            }
        }
    }

    // MARK: - Collections Section

    var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Collections", icon: "mail.stack.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: twoRows, spacing: 10) {
                    ForEach(pinnedCollections.prefix(maxCards)) { collection in
                        NavigationLink(value: collection) {
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
        let count = entryCount(for: collection)
        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(accent.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
                )
            VStack(spacing: 6) {
                Image(systemName: collection.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(accent)
                Text(collection.name)
                    .font(style.typeCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("\(count)")
                    .font(style.typeCaption)
                    .foregroundStyle(accent.opacity(0.7))
            }
            .padding(8)
        }
        .frame(width: 95, height: 95)
    }

    // MARK: - Folios Section

    var foliosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Folios", icon: "book.pages.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(pinnedFolios) { folio in
                        NavigationLink(value: folio) {
                            folioPill(folio: folio)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
        }
    }

    func folioPill(folio: Collection) -> some View {
        HStack(spacing: 6) {
            Text(folio.folioEmoji ?? "◆").font(.system(size: 20))
            Text(folio.name)
                .font(style.typeBodySecondary)
                .fontWeight(.medium)
                .foregroundStyle(style.primaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: folio.colorHex).opacity(0.15))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(
                LinearGradient(
                    colors: [Color(white: 0.85), Color(white: 0.6),
                             Color(white: 0.85), Color(white: 0.5), Color(white: 0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
        )
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    // MARK: - Entries Section

    var entriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Bookmarks", icon: "bookmark.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(
                    rows: [GridItem(.fixed(80), spacing: 10), GridItem(.fixed(80), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(pinnedEntries.prefix(maxCards)) { entry in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedEntry = entry
                            }
                        } label: {
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
                        NavigationLink(value: person) {
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

    func compactPersonCard(person: Tag) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(SharedTheme.goldRingGradient, lineWidth: 1.5)
                    .frame(width: 58, height: 58)
                personAvatarView(person: person, size: 54)
            }
            Text(person.name)
                .font(style.typeCaption)
                .foregroundStyle(style.secondaryText)
                .lineLimit(1)
                .frame(width: 64)
        }
        .frame(width: 64, height: 80)
    }

    func personAvatarView(person: Tag, size: CGFloat) -> some View {
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
            FlowLayout(spacing: 8, maxRows: 3) {
                ForEach(pinnedTags, id: \.name) { tag in
                    NavigationLink(value: tag.name) {
                        tagPill(tag: tag)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    func tagPill(tag: Tag) -> some View {
        let count = allEntries.filter { $0.tagNames.contains(tag.name) }.count
        return HStack(spacing: 4) {
            Text(tag.name)
                .font(style.typeCaption)
                .foregroundStyle(style.accent)
            Text("(\(count))")
                .font(style.typeCaption)
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
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
    }

    // MARK: - Section Header

    func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(style.accent)
            Text(title)
                .font(style.typeTitle2)
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
                .font(style.typeTitle3)
                .foregroundStyle(style.secondaryText)
            Text("Bookmark entries, collections, tags, and people to see them here.")
                .font(style.typeCaption)
                .foregroundStyle(style.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 20)
    }
}
