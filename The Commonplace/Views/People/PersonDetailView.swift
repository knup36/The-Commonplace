// PersonDetailView.swift
// Commonplace
//
// Formal detail view for a Person Subject (Tag with subjectType == "person").
// Centered avatar with gold border, name, birthday, bio, then entry feed.
// Everything scrolls together in one unified ScrollView.
//
// Updated in v1.10.1 — now reads from Tag instead of Person model.
// People connect to entries via @-prefixed name matching:
//   entry.tagNames.contains("@" + tag.name)

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Bindable var tag: Tag
    @Query var allEntries: [Entry]
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingEditView = false
    
    var style: any AppThemeStyle { themeManager.style }
    var accent: Color { style.accent }
    
    var taggedEntries: [Entry] {
        allEntries
            .filter { $0.tagNames.contains("@\(tag.name)") }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                contactHeader
                
                Divider()
                    .overlay(style.tertiaryText.opacity(0.3))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                
                if !taggedEntries.isEmpty {
                    Text("\(taggedEntries.count) \(taggedEntries.count == 1 ? "entry" : "entries")")
                        .font(style.typeCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                
                if taggedEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundStyle(style.tertiaryText)
                        Text("No entries with \(tag.name) yet")
                            .font(style.typeBodySecondary)
                            .foregroundStyle(style.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                } else {
                    ForEach(taggedEntries) { entry in
                        NavigationLink(destination: destinationView(for: entry)) {
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
            PersonEditView(tag: tag)
        }
    }
    
    // MARK: - Contact Header
    
    var contactHeader: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(SharedTheme.goldRingGradient, lineWidth: 3.5)
                    .frame(width: 181, height: 181)
                
                avatarView(size: 175)
            }
            .padding(.top, 32)
            .padding(.bottom, 4)
            
            Text(tag.name)
                .font(style.typeTitle2)
                .fontWeight(.bold)
                .foregroundStyle(style.primaryText)
            
            if let birthdate = tag.birthdate {
                HStack(spacing: 5) {
                    Image(systemName: "birthday.cake")
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                    Text(birthdate.formatted(.dateTime.month(.wide).day().year()))
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.secondaryText)
                }
            }
            
            if let bio = tag.bio, !bio.isEmpty {
                Text(bio)
                    .font(style.typeBody)
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
            if let path = tag.profilePhotoPath,
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
                        Text(String(tag.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.4, weight: .light))
                            .foregroundStyle(accent)
                    )
            }
        }
    }
}
