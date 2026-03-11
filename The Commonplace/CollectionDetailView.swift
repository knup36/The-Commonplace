import SwiftUI
import SwiftData
import CoreLocation

struct CollectionDetailView: View {
    let collection: Collection
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""

    var isInkwell: Bool { themeManager.current == .inkwell }
    var accentColor: Color {
        isInkwell
            ? InkwellTheme.collectionAccentColor(for: collection.colorHex)
            : Color(hex: collection.colorHex)
    }

    var hasNonTypeFilters: Bool {
        !collection.filterTags.isEmpty ||
        collection.filterSearchText != nil ||
        collection.filterLocationName != nil ||
        (DateFilterRange(rawValue: collection.filterDateRange) ?? .allTime) != .allTime
    }

    var filteredEntries: [Entry] {
        let matched = entries
            .filter { collectionMatches(entry: $0, collection: collection) }
            .sorted { $0.createdAt > $1.createdAt }
        if searchText.isEmpty { return matched }
        return matched.filter { entryMatchesSearch($0, searchText: searchText) }
    }

    var body: some View {
        List {
            collectionHeader
            entryRows
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(isInkwell ? InkwellTheme.background : Color(uiColor: .systemBackground))
        .searchable(text: $searchText, prompt: "Search collection...")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sub-views

    var collectionHeader: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(InkwellTheme.collectionCardBackground(for: collection.colorHex))
                    .frame(width: 52, height: 52)
                    .overlay(
                        isInkwell
                        ? Circle().strokeBorder(
                            LinearGradient(
                                colors: [InkwellTheme.cardBorderTop, accentColor.opacity(0.2)],
                                startPoint: .top, endPoint: .bottom
                            ), lineWidth: 0.5)
                        : nil
                    )
                Image(systemName: collection.icon)
                    .font(.title2)
                    .foregroundStyle(isInkwell ? Color(hex: collection.colorHex) : accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(isInkwell ? .system(.title2, design: .serif) : .title2)
                    .fontWeight(.bold)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : accentColor)

                if hasNonTypeFilters {
                    filterChips
                }
            }

            Spacer()

            Text("\(filteredEntries.count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(accentColor)
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(icon: nil, label: "Collection")

                if !collection.filterTypes.isEmpty {
                    ForEach(collection.filterTypes, id: \.self) { type in
                        filterChip(icon: iconForEntryType(type), label: type.capitalized)
                    }
                }
                if !collection.filterTags.isEmpty {
                    ForEach(collection.filterTags, id: \.self) { tag in
                        filterChip(icon: "number", label: tag)
                    }
                }
                if let range = DateFilterRange(rawValue: collection.filterDateRange), range != .allTime {
                    filterChip(icon: "calendar", label: range.rawValue)
                }
                if let locationName = collection.filterLocationName {
                    filterChip(icon: "location.fill", label: "near \(locationName)")
                }
                if let st = collection.filterSearchText, !st.isEmpty, st != "__favorites__" {
                    filterChip(icon: "magnifyingglass", label: st)
                }
                if collection.filterSearchText == "__favorites__" {
                    filterChip(icon: "star.fill", label: "Favorites")
                }
            }
        }
    }

    func filterChip(icon: String?, label: String) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon).font(.caption)
            }
            Text(label).font(.caption)
        }
        .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
    }

    @ViewBuilder
    var entryRows: some View {
        ForEach(filteredEntries) { entry in
            ZStack {
                NavigationLink(destination: destinationView(for: entry)) {
                    EmptyView()
                }
                .opacity(0)
                EntryRowView(entry: entry)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    func destinationView(for entry: Entry) -> some View {
        switch entry.type {
        case .location: LocationDetailView(entry: entry)
        case .sticky:   StickyDetailView(entry: entry)
        default:        EntryDetailView(entry: entry)
        }
    }

    func iconForEntryType(_ type: String) -> String {
        switch type {
        case "text":     return "text.alignleft"
        case "photo":    return "photo"
        case "audio":    return "waveform"
        case "link":     return "link"
        case "journal":  return "bookmark.fill"
        case "location": return "mappin.circle.fill"
        case "sticky":   return "checklist"
        default:         return "square"
        }
    }
}
