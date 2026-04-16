import SwiftUI
import SwiftData
import CoreLocation

// When tapping on a collection, this is the view it takes you to

struct CollectionDetailView: View {
    let collection: Collection
    @Query var entries: [Entry]
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""
    @State private var showingAddEntry: Bool = false
    @State private var showingTemplatePicker: Bool = false
    
    var style: any AppThemeStyle { themeManager.style }
    var accentColor: Color {
        Color(hex: collection.colorHex)
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
        ScrollView {
            LazyVStack(spacing: 0) {
                collectionHeader
                if filteredEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(style.tertiaryText)
                        Text("Nothing matches these filters")
                            .font(style.typeBodySecondary)
                            .foregroundStyle(style.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    entryRows
                }
            }
        }
        .background(style.background)
        .searchable(text: $searchText, prompt: "Search collection...")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            ThoughtCaptureBar(
                showFullBar: false,
                showingAddEntry: $showingAddEntry,
                showingTemplatePicker: $showingTemplatePicker,
                contextTags: collection.filterTags
            )
        }
    }
    
    // MARK: - Sub-views
    
    var collectionHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle().strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
                    )
                Image(systemName: collection.icon)
                    .font(.title2)
                    .foregroundStyle(accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(style.typeTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(style.primaryText)
                
                if hasNonTypeFilters {
                    filterChips
                }
            }
            
            Spacer()
            
            Text("\(filteredEntries.count)")
                .font(style.typeLargeTitle)
                .fontWeight(.bold)
                .foregroundStyle(accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(icon: nil, label: "Collection")
                
                if !collection.filterTypes.isEmpty {
                    ForEach(collection.filterTypes, id: \.self) { type in
                        filterChip(icon: EntryType(rawValue: type)?.icon, label: type.capitalized)
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
        .foregroundStyle(style.secondaryText)
    }
    
    @ViewBuilder
    var entryRows: some View {
        ForEach(filteredEntries) { entry in
            NavigationLink(destination: NavigationRouter.destination(for: entry)) {
                EntryRowView(entry: entry)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}
