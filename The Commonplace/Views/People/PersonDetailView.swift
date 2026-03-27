// PersonDetailView.swift
// Commonplace
//
// Formal detail view for a Person object.
// Centered avatar with gold border, name, birthday, bio, then entry feed.
// Everything scrolls together in one unified ScrollView — personal info
// slides up and off screen naturally as the user scrolls into entries.
//
// Layout: ScrollView + LazyVStack (no List — full design control, no background fighting)
//
// Editing via PersonEditView sheet, accessible from Edit button in toolbar.
//
// People connect to entries via name matching:
//   entry.tagNames.contains("@" + person.name)

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Bindable var person: Person
    @Query var allEntries: [Entry]
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingEditView = false

    var style: any AppThemeStyle { themeManager.style }
    var accent: Color { style.accent }

    var taggedEntries: [Entry] {
        allEntries
            .filter { $0.tagNames.contains(person.tagString) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Contact header
                contactHeader

                // Divider
                Divider()
                    .overlay(style.usesSerifFonts ? InkwellTheme.cardBorderTop : Color(uiColor: .separator))
                    .opacity(style.usesSerifFonts ? 0.6 : 1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                // Entry count
                if !taggedEntries.isEmpty {
                    Text("\(taggedEntries.count) \(taggedEntries.count == 1 ? "entry" : "entries")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                // Entry feed
                if taggedEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundStyle(style.tertiaryText)
                        Text("No entries with \(person.name) yet")
                            .font(.subheadline)
                            .foregroundStyle(style.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                } else {
                    ForEach(taggedEntries) { entry in
                        ZStack {
                            NavigationLink(destination: destinationView(for: entry)) {
                                EmptyView()
                            }
                            .opacity(0)
                            EntryRowView(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                    .padding(.bottom, 3)
                }
            }
        }
        .background(style.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditView = true
                }
                .foregroundStyle(accent)
            }
        }
        .sheet(isPresented: $showingEditView) {
            PersonEditView(person: person)
        }
    }

    // MARK: - Contact Header

    var contactHeader: some View {
        VStack(alignment: .center, spacing: 12) {
            // Avatar with gold border
            ZStack {
                Circle()
                    .strokeBorder(accent, lineWidth: 2)
                    .frame(width: 181, height: 181)

                avatarView(size: 175)
            }
            .padding(.top, 32)
            .padding(.bottom, 4)

            // Name
            Text(person.name)
                .font(style.usesSerifFonts
                      ? .system(.title2, design: .serif)
                      : .title2)
                .fontWeight(.bold)
                .foregroundStyle(style.primaryText)

            // Birthday
            if let birthdate = person.birthdate {
                HStack(spacing: 5) {
                    Image(systemName: "birthday.cake")
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                    Text(birthdate.formatted(.dateTime.month(.wide).day().year()))
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryText)
                }
            }

            // Bio
            if let bio = person.bio, !bio.isEmpty {
                Text(bio)
                    .font(style.usesSerifFonts
                          ? .system(.body, design: .serif)
                          : .body)
                    .italic(style.usesSerifFonts)
                    .foregroundStyle(style.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }

    // MARK: - Avatar

    func avatarView(size: CGFloat) -> some View {
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
                    .fill(accent.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.4, weight: .light))
                            .foregroundStyle(accent)
                    )
            }
        }
    }
}
