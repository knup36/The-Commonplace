// PersonEditView.swift
// Commonplace
//
// Edit sheet for a Person object.
// Accessible via the Edit button on PersonDetailView.
//
// Allows editing:
//   - Profile photo (with crop/zoom via UIImagePickerController)
//   - Name
//   - Bio
//   - Birthdate
//
// All changes save immediately to SwiftData.
// Dismiss via Done button in toolbar.

import SwiftUI
import SwiftData
import PhotosUI

struct PersonEditView: View {
    @Bindable var person: Person
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var nameText: String = ""
    @State private var bioText: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingDatePicker = false
    
    var style: any AppThemeStyle { themeManager.style }
    var accent: Color { style.accent }
    
    var body: some View {
        NavigationStack {
            Form {
                // Photo section
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                avatarView(size: 100)
                                Circle()
                                    .fill(accent)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(style.usesSerifFonts ? style.surface : nil)
                }
                
                // Name
                Section {
                    TextField("Name", text: $nameText)
                        .font(style.usesSerifFonts ? .system(.body, design: .serif) : .body)
                        .foregroundStyle(style.primaryText)
                        .listRowBackground(style.usesSerifFonts ? style.surface : nil)
                } header: {
                    Text("Name")
                        .foregroundStyle(style.tertiaryText)
                }
                
                // Bio
                Section {
                    TextField("Add a bio...", text: $bioText, axis: .vertical)
                        .font(style.usesSerifFonts ? .system(.body, design: .serif) : .body)
                        .foregroundStyle(style.primaryText)
                        .lineLimit(3...6)
                        .listRowBackground(style.usesSerifFonts ? style.surface : nil)
                } header: {
                    Text("Bio")
                        .foregroundStyle(style.tertiaryText)
                }
                
                // Birthday
                Section {
                    if showingDatePicker {
                        DatePicker(
                            "Birthday",
                            selection: Binding(
                                get: { person.birthdate ?? Date() },
                                set: { person.birthdate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .listRowBackground(style.usesSerifFonts ? style.surface : nil)
                        
                        Button("Remove Birthday") {
                            person.birthdate = nil
                            showingDatePicker = false
                        }
                        .foregroundStyle(.red)
                        .listRowBackground(style.usesSerifFonts ? style.surface : nil)
                    } else {
                        Button {
                            showingDatePicker = true
                        } label: {
                            HStack {
                                Text(person.birthdate != nil
                                     ? person.birthdate!.formatted(.dateTime.month(.wide).day().year())
                                     : "Add Birthday")
                                .foregroundStyle(person.birthdate != nil ? style.primaryText : style.tertiaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(style.tertiaryText)
                            }
                        }
                        .listRowBackground(style.usesSerifFonts ? style.surface : nil)
                    }
                } header: {
                    Text("Birthday")
                        .foregroundStyle(style.tertiaryText)
                }
            }
            .scrollContentBackground(style.usesSerifFonts ? .hidden : .visible)
            .background(style.usesSerifFonts ? style.background : Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                    .bold()
                    .foregroundStyle(accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(style.secondaryText)
                }
            }
            .onAppear {
                nameText = person.name
                bioText = person.bio ?? ""
            }
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
                    try? modelContext.save()
                }
            }
        }
    }
    
    // MARK: - Save
    
    func save() {
        let trimmedName = nameText.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            person.name = trimmedName
        }
        person.bio = bioText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : bioText.trimmingCharacters(in: .whitespaces)
        try? modelContext.save()
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
