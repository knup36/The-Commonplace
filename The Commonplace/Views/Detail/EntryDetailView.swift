import SwiftUI
import SwiftData
import MapKit

// MARK: - EntryDetailView
// Main detail view for all entry types.
// Acts as a container that delegates to type-specific section views.
// Handles text editing, toolbar, metadata footer, and search indexing on disappear.
// Screen: Entry Detail (tap any entry in the Feed, Collections, Tags, or Today tab)

struct EntryDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var entry: Entry
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var textFieldFocused: Bool
    
    var style: any AppThemeStyle { themeManager.style }

    var entryColor: Color {
        InkwellTheme.cardBackground(for: entry.type)
    }

    var entryAccentColor: Color {
        switch entry.type {
        case .text:     return InkwellTheme.inkSecondary
        case .photo:    return InkwellTheme.collectionAccentColor(for: "#FF375F")
        case .audio:    return InkwellTheme.collectionAccentColor(for: "#FF9F0A")
        case .link:     return InkwellTheme.collectionAccentColor(for: "#0A84FF")
        case .journal:  return InkwellTheme.journalAccent
        case .location: return InkwellTheme.collectionAccentColor(for: "#30D158")
        case .sticky:   return InkwellTheme.amber
        case .music:    return InkwellTheme.accentColor(for: .music)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhotoDetailSection(entry: entry, style: style, accentColor: entryAccentColor)
                AudioDetailSection(entry: entry, style: style, accentColor: entryAccentColor)
                LinkDetailSection(entry: entry, style: style, accentColor: entryAccentColor)
                MusicDetailSection(entry: entry, style: style, accentColor: entryAccentColor)
                JournalMetadataSection(entry: entry, style: style, accentColor: entryAccentColor)
                textContentSection
                TagInputView(tags: $entry.tags, accentColor: entryAccentColor, style: style)
                Divider()
                metadataFooter
            }
            .padding()
        }
        .background(entryColor.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 100)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if isEditing {
                        Button("Done") {
                            entry.text = editText
                            isEditing = false
                            textFieldFocused = false
                        }
                        .bold()
                        .foregroundStyle(style.accent)
                    }
                    Button {
                        withAnimation { entry.isFavorited.toggle() }
                    } label: {
                        Image(systemName: entry.isFavorited ? "star.fill" : "star")
                            .foregroundStyle(style.accent)
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if entry.type == .text && entry.text.isEmpty {
                    editText = entry.text
                    isEditing = true
                    textFieldFocused = true
                }
            }
        }
        .onDisappear {
            SearchIndex.shared.index(entry: entry)
        }
    }

    // MARK: - Text Content Section

    @ViewBuilder
    var textContentSection: some View {
        if isEditing {
            AutoResizingTextEditor(text: $editText, minHeight: 32)
                .focused($textFieldFocused)
                .font(style.body)
                .foregroundStyle(style.primaryText)
                .onChange(of: editText) { _, newValue in entry.text = newValue }
        } else {
            Text(entry.text.isEmpty ? "" : entry.text)
                .font(style.body)
                .foregroundStyle(style.primaryText)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    editText = entry.text
                    isEditing = true
                    textFieldFocused = true
                }
        }
    }

    // MARK: - Metadata Footer

    var metadataFooter: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.createdAt.formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                if let lat = entry.captureLatitude, let lon = entry.captureLongitude {
                    Button {
                        openInMaps(lat: lat, lon: lon, name: entry.captureLocationName)
                    } label: {
                        Label(
                            entry.captureLocationName ?? "\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))",
                            systemImage: "location.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(entryAccentColor)
                            .frame(width: 20, height: 20)
                        Image(systemName: entry.type.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(style.background)
                    }
                    Text(entry.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(entryAccentColor)
                }
                .padding(.leading, -5)
                .padding(.top, 3)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    func openInMaps(lat: Double, lon: Double, name: String?) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name ?? "Entry Location"
        mapItem.openInMaps()
    }
}
