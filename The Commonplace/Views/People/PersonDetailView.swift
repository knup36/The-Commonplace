// PersonDetailView.swift
// Commonplace
//
// Detail view for a Person object.
// Shows a contact card header (avatar, name, bio, birthdate)
// followed by a full feed of all entries tagged with this person.
//
// People are connected to entries via name matching:
//   entry.tagNames.contains("@" + person.name)
//
// Editing person metadata (photo, bio, birthdate) is done inline.
// Profile photos are stored via MediaFileManager.

import SwiftUI
import SwiftData
import PhotosUI

struct PersonDetailView: View {
    @Bindable var person: Person
    @Query var allEntries: [Entry]
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var bioText = ""
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingDatePicker = false
    @FocusState private var bioFieldFocused: Bool
    
    var style: any AppThemeStyle { themeManager.style }
    var accent: Color { style.accent }
    
    var taggedEntries: [Entry] {
        allEntries
            .filter { $0.tagNames.contains(person.tagString) }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        List {
            // Contact card header
            contactCard
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            
            // Entry count header
            if !taggedEntries.isEmpty {
                Text("\(taggedEntries.count) \(taggedEntries.count == 1 ? "entry" : "entries")")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(style.secondaryText)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            
            // Entry feed
            ForEach(taggedEntries) { entry in
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
                .padding(.top, 40)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(style.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if bioFieldFocused {
                    Button("Done") {
                        bioFieldFocused = false
                    }
                    .foregroundStyle(accent)
                }
            }
        }
        .onAppear { bioText = person.bio ?? "" }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem,
                      let rawData = try? await newItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: rawData),
                      let processed = ImageProcessor.resizeAndCompress(image: uiImage) else { return }
                person.profilePhotoPath = try? MediaFileManager.save(
                    processed,
                    type: .image,
                    id: "\(person.id.uuidString)_avatar"
                )
            }
        }
    }
    
    // MARK: - Contact Card
    
    var contactCard: some View {
        VStack(spacing: 16) {
            // Avatar + photo picker
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    avatarView(size: 160)
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(accent)
                        .background(Circle().fill(style.background).padding(2))
                }
            }
            .buttonStyle(.plain)
            
            // Name
            Text(person.name)
                .font(style.usesSerifFonts
                      ? .system(.title2, design: .serif)
                      : .title2)
                .fontWeight(.bold)
                .foregroundStyle(style.primaryText)
            
            // Bio — always editable, saves on change
            TextField("Add a bio...", text: $bioText, axis: .vertical)
                .font(style.usesSerifFonts ? .system(.body, design: .serif) : .body)
                .foregroundStyle(style.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1...4)
                .focused($bioFieldFocused)
                .onChange(of: bioText) { _, newValue in
                    person.bio = newValue.isEmpty ? nil : newValue
                    try? modelContext.save()
                }
            
            // Birthdate
            if showingDatePicker {
                VStack(spacing: 8) {
                    DatePicker(
                        "Birthday",
                        selection: Binding(
                            get: { person.birthdate ?? Date() },
                            set: {
                                person.birthdate = $0
                                try? modelContext.save()
                            }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    
                    Button("Done") {
                        showingDatePicker = false
                        try? modelContext.save()
                    }
                    .font(.caption)
                    .foregroundStyle(accent)
                }
            } else {
                Button {
                    showingDatePicker = true
                } label: {
                    if let birthdate = person.birthdate {
                        Label(birthdate.formatted(.dateTime.month(.wide).day().year()), systemImage: "birthday.cake")
                            .font(.caption)
                            .foregroundStyle(style.secondaryText)
                    } else {
                        Label("Add birthday", systemImage: "birthday.cake")
                            .font(.caption)
                            .foregroundStyle(style.tertiaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
                    .fill(accent.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(accent)
                    )
            }
        }
    }
}
