// RewindCard.swift
// Commonplace
//
// Chronicles card that lets the user pick an arbitrary date range and
// browse everything captured in that window — a personal documentary
// of a chosen period.
//
// Display: photo grid on top, slim entry rows below, newest first.
// Date filtering happens on tap, not on every render.

import SwiftUI

struct RewindCard: View {
    let allEntries: [Entry]
    let style: any AppThemeStyle
    let themeManager: ThemeManager
    
    // MARK: - State
    
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var filteredEntries: [Entry] = []
    @State private var hasSearched: Bool = false
    @State private var showingAll: Bool = false
    
    // MARK: - Derived
    
    var photoEntries: [Entry] {
        filteredEntries.filter { $0.type == .photo && $0.imagePath != nil }
    }
    
    var nonPhotoEntries: [Entry] {
        filteredEntries.filter { $0.type != .photo || $0.imagePath == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var visibleNonPhotoEntries: [Entry] {
        showingAll ? nonPhotoEntries : Array(nonPhotoEntries.prefix(5))
    }
    
    var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
    
    // MARK: - Body
    
    var body: some View {
        ChroniclesCardContainer(title: "Rewind", icon: "backward.fill", cardID: "rewind", background: .parchment) {
            if !hasSearched {
                datePicker
            } else {
                results
            }
        }
    }
    
    // MARK: - Date picker
    
    var datePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Text("From")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(ChroniclesTheme.secondaryText)
                        .frame(width: 44, alignment: .leading)
                    DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .tint(ChroniclesTheme.accentAmber)
                                            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                                            .fixedSize()
                                            .id("from-\(Locale(identifier: "en_US_POSIX").identifier)")
                    Spacer()
                }
                HStack(spacing: 16) {
                    Text("To")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(ChroniclesTheme.secondaryText)
                        .frame(width: 44, alignment: .leading)
                    DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .tint(ChroniclesTheme.accentAmber)
                                            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                                            .fixedSize()
                                            .id("to-\(Locale(identifier: "en_US_POSIX").identifier)")
                    Spacer()
                }
            }
            
            Button {
                search()
            } label: {
                Text("Show Entries")
                    .font(style.typeBodySecondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(ChroniclesTheme.accentAmber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(ChroniclesTheme.accentAmber.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Results
    
    var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Date range label + reset
            HStack {
                Text(dateRangeLabel)
                    .font(style.typeCaption)
                    .foregroundStyle(ChroniclesTheme.secondaryText)
                Spacer()
                Button {
                    hasSearched = false
                    filteredEntries = []
                    showingAll = false
                } label: {
                    Text("Reset")
                        .font(style.typeCaption)
                        .foregroundStyle(ChroniclesTheme.accentAmber)
                }
                .buttonStyle(.plain)
            }
            
            if filteredEntries.isEmpty {
                Text("Nothing captured in this period.")
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.tertiaryText)
            } else {
                
                // Photo grid
                if !photoEntries.isEmpty {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4),
                        spacing: 3
                    ) {
                        ForEach(photoEntries) { entry in
                            NavigationLink(value: entry) {
                                photoThumb(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Slim entry rows
                if !nonPhotoEntries.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(visibleNonPhotoEntries) { entry in
                            NavigationLink(value: entry) {
                                entryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            if entry.id != visibleNonPhotoEntries.last?.id {
                                Divider()
                                    .overlay(ChroniclesTheme.sectionDivider)
                                    .padding(.leading, 36)
                            }
                        }
                        
                        if !showingAll && nonPhotoEntries.count > 5 {
                            Button {
                                showingAll = true
                            } label: {
                                Text("\(nonPhotoEntries.count - 5) more from this period")
                                    .font(style.typeCaption)
                                    .foregroundStyle(style.accent)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.top, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Photo thumb
    
    func photoThumb(entry: Entry) -> some View {
        GeometryReader { geo in
            Group {
                if let path = entry.imagePath,
                   let data = MediaFileManager.load(path: path),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(ChroniclesTheme.cardGradient)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(ChroniclesTheme.tertiaryText)
                        )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Entry row
    
    func entryRow(entry: Entry) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(entry.type.accentColor(for: themeManager.current).opacity(0.25))
                    .frame(width: 28, height: 28)
                Image(systemName: entry.type.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(entry.type.accentColor(for: themeManager.current).opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(previewText(for: entry))
                    .font(style.typeBodySecondary)
                    .foregroundStyle(ChroniclesTheme.primaryText)
                    .lineLimit(2)
                Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(style.typeCaption)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ChroniclesTheme.tertiaryText)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    
    func search() {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        filteredEntries = allEntries
            .filter { $0.createdAt >= start && $0.createdAt <= end }
            .sorted { $0.createdAt > $1.createdAt }
        hasSearched = true
        showingAll = false
    }
    
    func previewText(for entry: Entry) -> String {
        switch entry.type {
        case .location: return entry.locationName ?? "A place"
        case .link:     return entry.linkTitle ?? entry.url ?? "A link"
        case .media:    return entry.mediaTitle ?? "A media entry"
        case .music:    return entry.linkTitle ?? "A track"
        case .sticky:   return entry.stickyTitle ?? "A list"
        case .audio:    return entry.text.components(separatedBy: "\n").first
                .flatMap { $0.isEmpty ? nil : $0 } ?? "A recording"
        default:
            let firstLine = entry.text.components(separatedBy: "\n").first ?? ""
            let text = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? entry.type.displayName : text
        }
    }
}
