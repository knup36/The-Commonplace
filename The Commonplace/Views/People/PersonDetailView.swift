// PersonDetailView.swift
// Commonplace
//
// Detail view for a Person object.
// Full bleed profile photo as background via .background modifier.
// Name, birthday, and bio float over the photo.
// Entry feed scrolls below.
//
// Editing is done via PersonEditView, accessible from the Edit button.
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
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Transparent hero area — photo shows through
                heroArea
                
                // Feed area — solid background
                feedArea
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(photoBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditView = true
                }
                .foregroundStyle(.white)
            }
        }
        .sheet(isPresented: $showingEditView) {
            PersonEditView(person: person)
        }
    }
    
    // MARK: - Photo Background
    
    @ViewBuilder
    var photoBackground: some View {
        if let path = person.profilePhotoPath,
           let data = MediaFileManager.load(path: path),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [accent.opacity(0.7), accent.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .overlay(
                Text(String(person.name.prefix(1)).uppercased())
                    .font(.system(size: 140, weight: .thin))
                    .foregroundStyle(.white.opacity(0.2))
            )
        }
    }
    
    // MARK: - Hero Area
    
    var heroArea: some View {
        VStack(spacing: 6) {
            Spacer()
            Text(person.name)
                .font(style.usesSerifFonts
                      ? .system(.largeTitle, design: .serif)
                      : .largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
            
            if let birthdate = person.birthdate {
                HStack(spacing: 4) {
                    Image(systemName: "birthday.cake")
                        .font(.caption)
                    Text(birthdate.formatted(.dateTime.month(.wide).day().year()))
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            
            if let bio = person.bio, !bio.isEmpty {
                Text(bio)
                    .font(style.usesSerifFonts
                          ? .system(.body, design: .serif)
                          : .body)
                    .italic(style.usesSerifFonts)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.bottom, 24)
        .frame(height: 420)
    }
    
    // MARK: - Feed Area
    
    var feedArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !taggedEntries.isEmpty {
                Text("\(taggedEntries.count) \(taggedEntries.count == 1 ? "entry" : "entries")")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
            }
            
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
                    NavigationLink(destination: destinationView(for: entry)) {
                        EntryRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
